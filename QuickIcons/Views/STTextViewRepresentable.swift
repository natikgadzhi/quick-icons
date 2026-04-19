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
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isHorizontallyResizable = false
        textView.highlightSelectedLine = true

        // Line-number gutter
        textView.showsLineNumbers = true

        // Delegate for text-change callbacks
        textView.textDelegate = context.coordinator

        // Swift syntax highlighting via Plugin-Neon (tree-sitter).
        // Theme.default ships inside the plugin bundle and is NSAppearance-aware
        // (uses NSColor asset catalog entries that adapt to light/dark mode).
        textView.addPlugin(NeonPlugin(theme: .default, language: .swift))

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

        /// Shared diagnostics service.
        private let diagnosticsService = SourceKitDiagnosticsService()

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
            // with a 300ms debounce using Swift structured concurrency.
            diagnosticsTask?.cancel()
            diagnosticsTask = Task { [weak self, weak textView] in
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    // Task was cancelled — a newer keystroke supersedes this one.
                    return
                }

                guard let self, !Task.isCancelled else { return }

                let source = await MainActor.run { textView?.text ?? "" }
                let diagnostics = await self.diagnosticsService.diagnostics(for: source)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let textView else { return }
                    self.applyDiagnostics(diagnostics, to: textView)
                }
            }
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
        private func textLocation(
            forLine line: Int,
            in source: String,
            textView: STTextView
        ) -> (any NSTextLocation)? {
            guard line >= 1 else { return nil }

            // Find the character offset of the start of the given line (1-based).
            var currentLine = 1
            var characterOffset = 0
            for character in source {
                if currentLine == line { break }
                if character == "\n" { currentLine += 1 }
                characterOffset += 1
            }

            guard currentLine == line else { return nil }

            return textView.textLayoutManager.location(
                textView.textLayoutManager.documentRange.location,
                offsetBy: characterOffset
            )
        }
    }
}
