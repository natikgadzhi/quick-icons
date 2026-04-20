import AppKit
import SwiftUI
import STTextView
import STPluginNeon
import STAnnotationsPlugin
import STTextKitPlus
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
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay

        guard let textView = scrollView.documentView as? STTextView else {
            return scrollView
        }

        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isHorizontallyResizable = false

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        textView.defaultParagraphStyle = paragraphStyle

        textView.isIncrementalSearchingEnabled = true
        textView.usesFontPanel = false
        textView.showsInvisibleCharacters = showsInvisibles

        textView.highlightSelectedLine = true
        textView.selectedLineHighlightColor = NSColor(name: "xcodeCurrentLine") { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua: return NSColor(white: 1.0, alpha: 0.08)
            default:        return NSColor(rgb: 0xE8F0FE)
            }
        }

        textView.showsLineNumbers = true

        // Trailing inset reserves empty space for DiagnosticMarkerView's circle
        // so it doesn't overlap the right-aligned line-number digit.
        if let gutter = textView.gutterView {
            gutter.drawSeparator = true
            gutter.insets = STRulerInsets(leading: 4.0, trailing: 20.0)
            gutter.minimumThickness = max(gutter.minimumThickness, 50)
            gutter.textColor = NSColor.xcodeToken(light: 0x8A9BAC, dark: 0x6C7986)
        }

        textView.textDelegate = context.coordinator
        textView.addPlugin(NeonPlugin(theme: .xcode, language: .swift))

        let annotationsPlugin = STAnnotationsPlugin(dataSource: context.coordinator)
        context.coordinator.annotationsPlugin = annotationsPlugin
        textView.addPlugin(annotationsPlugin)

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

        /// Reentrancy guard for auto-indent. While true, `shouldChangeTextIn`
        /// passes newlines through untouched so the Coordinator-initiated
        /// `insertText("\n" + indent)` edit reaches the document instead of
        /// being intercepted again.
        private var isInsertingAutoIndent = false

        /// Reference to the annotations plugin so we can trigger reloads.
        weak var annotationsPlugin: STAnnotationsPlugin?

        /// Current annotations shown in the text view.
        var textViewAnnotations: [any STLineAnnotation] = [] {
            didSet {
                annotationsPlugin?.reloadAnnotations()
            }
        }

        /// Line numbers (1-based) for gutter markers we installed from the
        /// latest diagnostics batch. Tracked separately so subsequent updates
        /// can remove only our markers without clobbering any user-added ones.
        private var diagnosticMarkerLines: Set<Int> = []

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

        deinit {
            completionTask?.cancel()
        }

        // MARK: - STTextViewDelegate

        /// Intercepts plain newline insertions so we can auto-indent to match
        /// the previous line (and deepen one level after `{`).
        ///
        /// When the replacement string is exactly `"\n"` we compute the
        /// indentation for the caret's line, return `false` to prevent the
        /// default newline insertion, and then schedule our own
        /// `insertText("\n" + indent)` edit. That single edit keeps undo
        /// coalesced — one Cmd-Z undoes both the newline and the indent.
        /// The `isInsertingAutoIndent` flag breaks the reentrant call so our
        /// own insertion is not intercepted again.
        func textView(
            _ textView: STTextView,
            shouldChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String?
        ) -> Bool {
            guard !isInsertingAutoIndent,
                  replacementString == "\n",
                  affectedCharRange.isEmpty else {
                return true
            }

            let source = textView.text ?? ""
            let utf16Offset = textView.textLayoutManager.offset(
                from: textView.textLayoutManager.documentRange.location,
                to: affectedCharRange.location
            )
            guard utf16Offset >= 0 else { return true }

            let indent = AutoIndent.indent(
                source: source,
                insertionPointUTF16Offset: utf16Offset
            )

            // No indent to add → let STTextView perform its default newline.
            guard !indent.isEmpty else { return true }

            isInsertingAutoIndent = true
            defer { isInsertingAutoIndent = false }
            textView.insertText("\n" + indent, replacementRange: textView.selectedRange())
            return false
        }

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

            // Kick off STTextView's completion machinery. The delegate below
            // cancels and replaces the Coordinator-owned `completionTask`,
            // which carries the 200ms debounce + sourcekitd round-trip.
            // Coordinator teardown cancels any in-flight task via `deinit`.
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

        /// Inserts the selected completion into the text view, replacing the
        /// identifier prefix the user already typed at the caret with the item's
        /// `plainInsertText`. Placeholder markers (`<#…#>`) are stripped to
        /// their visible labels; the first placeholder is selected so the user
        /// can type over it immediately (Xcode-style "argument tab stop"
        /// behavior, minus the rich snippet UI which STTextView does not yet
        /// support).
        func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
            guard let completion = item as? SwiftCompletionListItem else { return }
            let insertText = completion.plainInsertText
            guard !insertText.isEmpty else { return }

            let source = textView.text ?? ""
            let caretLocation = textView.textLayoutManager.insertionPointLocations.first
                ?? textView.textLayoutManager.textSelections.first?.textRanges.first?.endLocation
                ?? textView.textLayoutManager.documentRange.location
            let caretUTF16 = textView.textLayoutManager.offset(
                from: textView.textLayoutManager.documentRange.location,
                to: caretLocation
            )
            let prefixLength = Self.identifierPrefixLength(
                in: source,
                endingAtUTF16Offset: caretUTF16
            )

            // Replace [caret - prefix, caret) with the plain insert text.
            let replacementStartUTF16 = caretUTF16 - prefixLength
            guard replacementStartUTF16 >= 0,
                  let replacementStart = textView.textLayoutManager.location(
                    textView.textLayoutManager.documentRange.location,
                    offsetBy: replacementStartUTF16
                  ),
                  let replacementRange = NSTextRange(
                    location: replacementStart,
                    end: caretLocation
                  ) else {
                // Fallback: just insert at the current selection.
                textView.insertText(insertText, replacementRange: textView.selectedRange())
                return
            }

            textView.replaceCharacters(in: replacementRange, with: insertText)

            // If the insert contains a placeholder, select its label so the
            // user can type over it. Otherwise, leave the caret at the end.
            if let placeholderRange = completion.firstPlaceholderUTF16Range,
               let selectionStart = textView.textLayoutManager.location(
                replacementStart,
                offsetBy: placeholderRange.lowerBound
               ),
               let selectionEnd = textView.textLayoutManager.location(
                replacementStart,
                offsetBy: placeholderRange.upperBound
               ),
               let selectionRange = NSTextRange(location: selectionStart, end: selectionEnd) {
                textView.textLayoutManager.textSelections = [
                    NSTextSelection(
                        range: selectionRange,
                        affinity: .downstream,
                        granularity: .character
                    )
                ]
            }
        }

        /// Returns the length (in UTF-16 code units) of the identifier prefix
        /// ending at `endingAtUTF16Offset` inside `source`. Used to decide how
        /// much of the user's partial word to replace on completion insertion.
        /// An identifier character is `[A-Za-z0-9_]`; this mirrors what the
        /// SourceKit completion request considers a prefix.
        static func identifierPrefixLength(in source: String, endingAtUTF16Offset offset: Int) -> Int {
            guard offset > 0 else { return 0 }
            let utf16 = source.utf16
            guard let endIndex = utf16.index(
                utf16.startIndex,
                offsetBy: offset,
                limitedBy: utf16.endIndex
            ) else {
                return 0
            }
            var count = 0
            var cursor = endIndex
            while cursor > utf16.startIndex {
                let prev = utf16.index(before: cursor)
                let unit = utf16[prev]
                // Fast path: only ASCII identifier characters count as prefix.
                let isIdent = (unit >= 0x30 && unit <= 0x39)          // 0-9
                    || (unit >= 0x41 && unit <= 0x5A)                 // A-Z
                    || (unit >= 0x61 && unit <= 0x7A)                 // a-z
                    || unit == 0x5F                                   // _
                if !isIdent { break }
                count += 1
                cursor = prev
            }
            return count
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

            applyGutterMarkers(for: diagnostics, to: textView)
        }

        /// Installs a colored dot marker in the gutter for each diagnostic line.
        /// The most severe diagnostic on a given line wins (error > warning > note).
        /// Markers from the previous batch are removed before the new ones are
        /// installed, so the pass is idempotent across keystrokes.
        private func applyGutterMarkers(for diagnostics: [SwiftDiagnostic], to textView: STTextView) {
            guard let gutter = textView.gutterView else { return }

            // Remove markers we installed on the prior pass. User-installed
            // markers (e.g. from clicking the gutter) are untouched because
            // we only remove lines we own.
            for line in diagnosticMarkerLines {
                gutter.removeMarker(lineNumber: line)
            }
            diagnosticMarkerLines.removeAll(keepingCapacity: true)

            // Pick the most severe diagnostic per line.
            let worstByLine = Self.mostSevereByLine(diagnostics)

            for (line, severity) in worstByLine {
                let markerView = DiagnosticMarkerView(severity: severity)
                gutter.addMarker(STGutterMarker(lineNumber: line, view: markerView))
                diagnosticMarkerLines.insert(line)
            }
        }

        /// Returns a mapping of 1-based line number → most-severe severity for that
        /// line among `diagnostics`. Diagnostics with non-positive line numbers are
        /// ignored. Exposed (non-private) to keep the dedup rule directly testable.
        static func mostSevereByLine(_ diagnostics: [SwiftDiagnostic]) -> [Int: SwiftDiagnostic.Severity] {
            var worstByLine: [Int: SwiftDiagnostic.Severity] = [:]
            for diagnostic in diagnostics where diagnostic.line >= 1 {
                let current = worstByLine[diagnostic.line]
                if current == nil || severityRank(diagnostic.severity) > severityRank(current!) {
                    worstByLine[diagnostic.line] = diagnostic.severity
                }
            }
            return worstByLine
        }

        static func severityRank(_ severity: SwiftDiagnostic.Severity) -> Int {
            switch severity {
            case .error: return 2
            case .warning: return 1
            case .note: return 0
            }
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

/// Gutter marker for a diagnostic: a small filled circle in the trailing
/// portion of the gutter, colored by severity (red/orange/grey).
///
/// STGutterView sizes the marker view itself in `layoutMarkers()` — it spans
/// roughly the right 60% of the gutter and aligns vertically with the line
/// number. We just draw a small circle on the trailing edge; the extra
/// `insets.trailing` configured on STGutterView reserves empty space there
/// so the circle does not collide with the line-number digit.
private final class DiagnosticMarkerView: NSView {
    private let fillColor: NSColor

    init(severity: SwiftDiagnostic.Severity) {
        self.fillColor = switch severity {
        case .error: .systemRed
        case .warning: .systemOrange
        case .note: .systemGray
        }
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 10pt circle centered vertically on the line, nudged toward the
        // trailing edge of our (STGutterView-sized) bounds into the empty
        // zone created by the widened `insets.trailing`.
        let diameter: CGFloat = 10
        let trailingNudge: CGFloat = 5
        let circleRect = NSRect(
            x: bounds.maxX - diameter - trailingNudge,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        fillColor.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
    }
}
