import AppKit
import STTextView

/// Adapter that makes `SwiftCompletionItem` (a value type produced by
/// `SourceKitCompletionService`) usable as an `STCompletionItem` inside
/// STTextView's built-in completion popup.
///
/// Exposes:
/// * `view` — a two-row stack with the kind's SF Symbol icon, the human-
///   readable description, and a trailing type annotation when available.
/// * `plainInsertText` / `firstPlaceholderUTF16Range` — mirrors of the
///   `SwiftCompletionItem` fields the editor coordinator uses during the
///   `insertCompletionItem` delegate callback. STTextView's current completion
///   surface does not support rich snippet placeholders, so we insert plain
///   text and select the first placeholder's label so the user can type over
///   it. Rich snippet insertion is tracked for a follow-up.
struct SwiftCompletionListItem: STCompletionItem {
    let item: SwiftCompletionItem

    /// Stable identity for the table view. Description is stable across
    /// identical completions and unique enough in practice for one popup.
    var id: String { "\(item.kind.rawValue)|\(item.description)|\(item.sourcetext)" }

    /// Plain-text insertion — placeholder markers stripped to their visible labels.
    var plainInsertText: String { item.plainInsertText }

    /// UTF-16 range of the first placeholder inside `plainInsertText`.
    var firstPlaceholderUTF16Range: Range<Int>? { item.firstPlaceholderUTF16Range }

    var view: NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)

        let iconView = NSImageView()
        iconView.image = NSImage(
            systemSymbolName: item.kind.sfSymbolName,
            accessibilityDescription: item.kind.rawValue
        )
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let label = NSTextField(labelWithString: item.description)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(label)

        // Trailing type annotation — secondary color, pushed to the far right
        // via a flexible spacer so long descriptions truncate before the type.
        if let typeName = item.typeName, !typeName.isEmpty {
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(spacer)

            let typeLabel = NSTextField(labelWithString: typeName)
            typeLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            typeLabel.textColor = .secondaryLabelColor
            typeLabel.lineBreakMode = .byTruncatingTail
            typeLabel.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(typeLabel)
        }
        return row
    }
}
