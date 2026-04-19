import AppKit
import SwiftUI
import STTextView

/// NSViewRepresentable wrapper around STTextView.
/// Provides a two-way binding to a plain-text String, a monospaced font,
/// and a visible line-number gutter. Plugin setup is intentionally left
/// empty so tasks 05 and 08 can add Neon / Annotations cleanly.
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

        // Set initial content
        textView.text = text

        // Plugins: empty for now — tasks 05 / 08 add Neon and Annotations here.

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
