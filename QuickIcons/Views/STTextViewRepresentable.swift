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
    /// Called on the main actor whenever the diagnostics availability changes —
    /// `true` means the latest sourcekitd diagnostics request failed (crashed,
    /// timed out, or was unreachable) and the UI should surface an "unavailable"
    /// affordance. `false` means the most recent request succeeded.
    var onDiagnosticsAvailabilityChange: ((Bool) -> Void)? = nil

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onDiagnosticsAvailabilityChange: onDiagnosticsAvailabilityChange)
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
        context.coordinator.diagnostics.annotationsPlugin = annotationsPlugin
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

    /// Thin shell that adapts STTextView delegate callbacks to the SwiftUI
    /// binding and to two focused helpers:
    ///  - `DiagnosticsCoordinator` for diagnostics requests + annotations + gutter.
    ///  - `CompletionCoordinator` for code-completion requests + insertion.
    ///
    /// The only editor concern that lives here is auto-indent, because it's
    /// tied directly to `shouldChangeTextIn` and is tiny.
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

        /// Diagnostics helper — owns its own debounce task and annotations plugin.
        let diagnostics: DiagnosticsCoordinator

        /// Completion helper — owns its own debounce task.
        let completion: CompletionCoordinator

        init(
            text: Binding<String>,
            diagnostics: DiagnosticsCoordinator? = nil,
            completion: CompletionCoordinator? = nil,
            onDiagnosticsAvailabilityChange: ((Bool) -> Void)? = nil
        ) {
            self.text = text
            self.diagnostics = diagnostics
                ?? DiagnosticsCoordinator(onAvailabilityChange: onDiagnosticsAvailabilityChange)
            self.completion = completion ?? CompletionCoordinator()
        }

        // MARK: - STAnnotationsDataSource

        var textViewAnnotations: [any STLineAnnotation] {
            get { diagnostics.textViewAnnotations }
            set { diagnostics.textViewAnnotations = newValue }
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

            diagnostics.scheduleDiagnostics(for: textView)

            // Kick off STTextView's completion machinery. The completion
            // delegate below asks `CompletionCoordinator` for the debounced
            // result per keystroke.
            textView.complete(self)
        }

        // MARK: - Completion delegate callbacks

        func textView(
            _ textView: STTextView,
            completionItemsAtLocation location: any NSTextLocation
        ) async -> [any STCompletionItem]? {
            await completion.completionItems(for: textView, at: location)
        }

        func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
            completion.insertCompletionItem(item, into: textView)
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
final class DiagnosticMarkerView: NSView {
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
