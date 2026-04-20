import AppKit
import STPluginNeon
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
        // When SourceKit emits an annotated description, render each run in
        // its Theme.xcode color. The palette's NSColors are appearance-aware
        // (`NSColor(name:dynamicProvider:)`), so AppKit re-resolves them on
        // light/dark flips with no rebuild.
        if let runs = item.annotatedDescription {
            label.attributedStringValue = Self.attributedString(
                runs: runs,
                font: label.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            )
        }

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

    /// Builds the attributed label for the completion row from parsed
    /// `AnnotatedRun`s. Each run's foreground color is pulled from
    /// `Theme.xcode`, which stores dynamic colors that resolve per appearance
    /// — so a single `NSAttributedString` renders correctly in both light
    /// and dark mode without rebuilding the string on appearance changes.
    static func attributedString(runs: [AnnotatedRun], font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let theme = Theme.xcode
        for run in runs {
            // Look up the color for this run's kind. The raw value of
            // `AnnotationKind` is the theme token name; falling back to
            // `plain` (and finally `labelColor`) keeps text readable even if
            // the theme and the annotation vocabulary drift apart.
            let color = theme.color(forToken: TokenName(run.kind.rawValue))
                ?? NSColor.labelColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            result.append(NSAttributedString(string: run.text, attributes: attrs))
        }
        return result
    }
}
