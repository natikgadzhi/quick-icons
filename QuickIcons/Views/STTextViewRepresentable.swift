import AppKit
import SwiftUI
import STTextView
import STPluginNeon
import TreeSitterResource

/// NSViewRepresentable wrapper around STTextView.
/// Provides a two-way binding to a plain-text String, a monospaced font,
/// a visible line-number gutter, and Swift syntax highlighting via Plugin-Neon.
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

    final class Coordinator: NSObject, STTextViewDelegate {
        var text: Binding<String>
        /// Guard flag: prevents the delegate callback from writing back while
        /// updateNSView is already applying a programmatic change.
        var isUpdatingFromSwiftUI = false

        init(text: Binding<String>) {
            self.text = text
        }

        // Called by STTextView after every user edit.
        func textViewDidChangeText(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI,
                  let textView = notification.object as? STTextView else { return }
            let newText = textView.text ?? ""
            if text.wrappedValue != newText {
                text.wrappedValue = newText
            }
        }
    }
}
