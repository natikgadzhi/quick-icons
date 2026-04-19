import AppKit
import SwiftUI
import STTextView
import STPluginNeon
import STAnnotationsPlugin
import TreeSitterResource

/// NSViewRepresentable wrapper around STTextView.
/// Provides a two-way binding to a plain-text String, a monospaced font,
/// a visible line-number gutter, Swift syntax highlighting via Plugin-Neon,
/// and inline diagnostics annotations via Plugin-Annotations.
struct STTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    var showsInvisibles: Bool = false
    var fontSize: CGFloat = 13

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? STTextView else {
            return scrollView
        }

        // Appearance
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isHorizontallyResizable = false

        // Paragraph style: give each line ~20% extra breathing room, matching
        // Xcode's default editor density. Both STTextView demos set this knob.
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        textView.defaultParagraphStyle = paragraphStyle

        // Editor-level polish: incremental ⌘F, no font-panel hijack of ⌘T,
        // and an initial state for the View → Show Invisible Characters toggle.
        textView.isIncrementalSearchingEnabled = true
        textView.usesFontPanel = false
        textView.showsInvisibleCharacters = showsInvisibles

        // Current-line highlight: matches Xcode's default editor behavior.
        // Light: #E8F0FE (faint blue-grey); Dark: ~8% white on the dark background.
        // NSColor(name:dynamicProvider:) resolves on every appearance change without
        // requiring an app restart.  STTextView hides the highlight automatically
        // when the selection spans more than a single insertion point — matching
        // Xcode's multi-line-selection behavior exactly.
        textView.highlightSelectedLine = true
        textView.selectedLineHighlightColor = NSColor(name: "xcodeCurrentLine") { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua: return NSColor(white: 1.0, alpha: 0.08)   // ~8% white
            default:        return NSColor(srgbRed: 0xE8/255, green: 0xF0/255, blue: 0xFE/255, alpha: 1.0) // #E8F0FE
            }
        }

        // Line-number gutter
        textView.showsLineNumbers = true

        // Gutter polish: separator line and markers enabled so later
        // breakpoint/diagnostic glyphs have somewhere to render. The gutter's
        // own highlightSelectedLine uses a different default color than the
        // editor's, which produces a saturated mismatch on click — leave it
        // off and let the editor-wide current-line highlight handle things.
        textView.gutterView?.drawSeparator = true
        textView.gutterView?.areMarkersEnabled = true

        // Delegate for text-change callbacks
        textView.textDelegate = context.coordinator

        // Swift syntax highlighting via Plugin-Neon (tree-sitter).
        // Theme.xcode mirrors Xcode's stock "Default (Light / Dark)" palette and
        // resolves dynamically per appearance — no restart required.
        textView.addPlugin(NeonPlugin(theme: .xcode, language: .swift))

        // Gutter: use Xcode's line-number text color (dynamic, light/dark).
        // STGutterView.backgroundColor is internal, so background is left to the
        // default NSVisualEffectView which already matches the editor tone.
        textView.gutterView?.textColor = NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua: return NSColor(srgbRed: 0x6C/255, green: 0x79/255, blue: 0x86/255, alpha: 1)
            default:        return NSColor(srgbRed: 0x8A/255, green: 0x9B/255, blue: 0xAC/255, alpha: 1)
            }
        }

        // Inline diagnostics via Plugin-Annotations.
        // The coordinator acts as data source; we keep a reference so the
        // coordinator can call reloadAnnotations() after updating its array.
        let annotationsPlugin = STAnnotationsPlugin(dataSource: context.coordinator)
        context.coordinator.annotationsPlugin = annotationsPlugin
        textView.addPlugin(annotationsPlugin)

        // Set initial content
        textView.text = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }

        // Only push a new value when SwiftUI state diverges from the editor,
        // to avoid clobbering the user's selection mid-edit.
        if textView.text != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.text = text
            context.coordinator.isUpdatingFromSwiftUI = false
        }

        if textView.showsInvisibleCharacters != showsInvisibles {
            textView.showsInvisibleCharacters = showsInvisibles
        }

        if textView.font.pointSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, STTextViewDelegate, STAnnotationsDataSource {
        var text: Binding<String>

        /// Guard flag: prevents the delegate callback from writing back while
        /// updateNSView is already applying a programmatic change.
        var isUpdatingFromSwiftUI = false

        /// Reference to the annotations plugin so we can trigger reloads.
        weak var annotationsPlugin: STAnnotationsPlugin?

        /// Current annotations shown in the text view.
        var textViewAnnotations: [any STLineAnnotation] = [] {
            didSet {
                annotationsPlugin?.reloadAnnotations()
            }
        }

        /// The pending diagnostics task. Cancelled and replaced on each keystroke.
        private var diagnosticsTask: Task<Void, Never>?

        /// The pending completion task. Cancelled and replaced on each keystroke,
        /// and automatically torn down when the Coordinator deallocates.
        private var completionTask: Task<[any STCompletionItem]?, Never>?

        /// Shared diagnostics service.
        private let diagnosticsService = SourceKitDiagnosticsService()

        /// Shared completion service (lazy: first call spins up sourcekitd).
        private let completionService = SourceKitCompletionService()

        init(text: Binding<String>) {
            self.text = text
        }

        // MARK: - STTextViewDelegate

        // Called by STTextView after every user edit.
        func textViewDidChangeText(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI,
                  let textView = notification.object as? STTextView else { return }
            let newText = textView.text ?? ""
            if text.wrappedValue != newText {
                text.wrappedValue = newText
            }

            // Cancel any in-flight diagnostics request, then schedule a new one
            // with a 700ms debounce. Long enough to absorb a `.` plus the next
            // identifier character without flashing a spurious error.
            diagnosticsTask?.cancel()
            diagnosticsTask = Task { [weak self, weak textView] in
                do {
                    try await Task.sleep(for: .milliseconds(700))
                } catch {
                    // Task was cancelled — a newer keystroke supersedes this one.
                    return
                }

                guard let self, !Task.isCancelled else { return }

                let source = textView?.text ?? ""
                let diagnostics = await self.diagnosticsService.diagnostics(for: source)

                guard !Task.isCancelled else { return }

                guard let textView else { return }
                self.applyDiagnostics(diagnostics, to: textView)
            }

            // Cancel any in-flight completion request and kick off STTextView's
            // completion machinery. The delegate below awaits the owned task,
            // which carries the 200ms debounce + sourcekitd round-trip. A new
            // keystroke cancels the prior task; Coordinator teardown cancels it
            // via ARC.
            completionTask?.cancel()
            textView.complete(self)
        }

        // MARK: - Completion

        /// STTextView's async completion hook.
        ///
        /// Each invocation cancel-and-replaces the Coordinator-owned
        /// `completionTask`, which runs the 200ms debounce and sourcekitd
        /// round-trip. The delegate awaits that task's value so STTextView
        /// receives a fresh, debounced result per keystroke. Returning `nil`
        /// or `[]` dismisses the popup.
        func textView(
            _ textView: STTextView,
            completionItemsAtLocation location: any NSTextLocation
        ) async -> [any STCompletionItem]? {
            let source = textView.text ?? ""
            let utf16Offset = textView.textLayoutManager.offset(
                from: textView.textLayoutManager.documentRange.location,
                to: location
            )
            guard utf16Offset >= 0 else { return nil }
            let byteOffset = utf8ByteOffset(forUTF16Offset: utf16Offset, in: source)

            completionTask?.cancel()
            let task = Task { [weak self] () -> [any STCompletionItem]? in
                // 200ms debounce — matches the spec; diagnostics use 700ms because
                // error annotations are higher-cost/noisier than a completion list.
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return nil
                }
                if Task.isCancelled { return nil }
                guard let self else { return nil }

                do {
                    let items = try await self.completionService.complete(
                        source: source,
                        offset: byteOffset
                    )
                    if Task.isCancelled { return nil }
                    return items.map { SwiftCompletionListItem(item: $0) }
                } catch {
                    return nil
                }
            }
            completionTask = task
            return await task.value
        }

        /// Converts a UTF-16 code-unit offset (what `NSTextLayoutManager.offset`
        /// returns) into the UTF-8 byte offset SourceKit expects.
        private func utf8ByteOffset(forUTF16Offset utf16Offset: Int, in source: String) -> Int {
            guard utf16Offset > 0 else { return 0 }
            guard let endIndex = source.utf16.index(
                source.utf16.startIndex,
                offsetBy: utf16Offset,
                limitedBy: source.utf16.endIndex
            ) else {
                return source.utf8.count
            }
            // Convert the UTF-16 index to a String.Index; fall back to the
            // full string if the offset lands mid-surrogate.
            guard let strIndex = endIndex.samePosition(in: source) else {
                return source.utf8.count
            }
            guard let utf8Index = strIndex.samePosition(in: source.utf8) else {
                return source.utf8.count
            }
            return source.utf8.distance(from: source.utf8.startIndex, to: utf8Index)
        }

        // MARK: - Diagnostics → Annotations

        private func applyDiagnostics(_ diagnostics: [SwiftDiagnostic], to textView: STTextView) {
            let source = textView.text ?? ""
            let annotations: [any STLineAnnotation] = diagnostics.compactMap { diagnostic in
                guard let location = textLocation(forLine: diagnostic.line, in: source, textView: textView) else {
                    return nil
                }

                let kind: STMessageLineAnnotation.AnnotationKind = switch diagnostic.severity {
                case .error: .error
                case .warning: .warning
                case .note: .info
                }

                return STMessageLineAnnotation(
                    id: "\(diagnostic.line):\(diagnostic.column):\(diagnostic.message)",
                    message: AttributedString(diagnostic.message),
                    kind: kind,
                    location: location
                )
            }
            textViewAnnotations = annotations
        }

        /// Converts a 1-based line number to an `NSTextLocation` inside the document.
        /// Returns `nil` when the line is out of range.
        func textLocation(
            forLine line: Int,
            in source: String,
            textView: STTextView
        ) -> (any NSTextLocation)? {
            guard line >= 1 else { return nil }

            let utf16Offset = utf16Offset(forLine: line, in: source)
            guard utf16Offset >= 0 else { return nil }

            return textView.textLayoutManager.location(
                textView.textLayoutManager.documentRange.location,
                offsetBy: utf16Offset
            )
        }

        /// Returns the UTF-16 offset of the start of `line` (1-based) within `source`.
        /// Returns `-1` when the line is out of range.
        func utf16Offset(forLine line: Int, in source: String) -> Int {
            guard line >= 1 else { return -1 }

            var currentLine = 1
            var utf16Count = 0
            for char in source {
                if currentLine == line { break }
                if char == "\n" { currentLine += 1 }
                utf16Count += char.utf16.count
            }

            guard currentLine == line else { return -1 }
            return utf16Count
        }
    }
}
