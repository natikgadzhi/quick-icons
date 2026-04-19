import AppKit
import STTextView

/// Adapter that makes `SwiftCompletionItem` (a value type produced by
/// `SourceKitCompletionService`) usable as an `STCompletionItem` inside
/// STTextView's built-in completion popup.
///
/// Stage 2 ships the minimum surface area the popup needs: an `Identifiable`
/// conformance and an `NSView` rendering that shows a kind icon and the
/// item's description. Stage 3 will refine the icon palette, layout, and
/// trailing type annotation.
struct SwiftCompletionListItem: STCompletionItem {
    let item: SwiftCompletionItem

    /// Stable identity for the table view. Description is stable across
    /// identical completions and unique enough in practice for one popup.
    var id: String { "\(item.kind.rawValue)|\(item.description)|\(item.sourcetext)" }

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
        return row
    }
}
