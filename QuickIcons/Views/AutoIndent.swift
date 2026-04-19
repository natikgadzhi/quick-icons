import Foundation

/// Pure helpers used by `STTextViewRepresentable.Coordinator` to compute the
/// indentation string to insert when the user presses Return.
///
/// Kept free of any `NSTextView` / `STTextView` dependency so the behavior can
/// be exercised by unit tests without standing up an AppKit view hierarchy.
enum AutoIndent {
    /// Returns the string that should follow the newline when the user presses
    /// Return at `insertionPointUTF16Offset` inside `source`.
    ///
    /// The result copies the leading whitespace of the current line verbatim
    /// (preserving tabs vs. spaces). If the character immediately before the
    /// insertion point is an opening brace `{`, one extra indent level
    /// (4 spaces) is appended.
    ///
    /// - Parameters:
    ///   - source: The full document text.
    ///   - insertionPointUTF16Offset: The caret position, measured in UTF-16
    ///     code units from the start of `source`. Values outside
    ///     `0...source.utf16.count` are clamped to the nearest end.
    /// - Returns: The indentation to insert after the newline (may be empty).
    static func indent(source: String, insertionPointUTF16Offset: Int) -> String {
        let utf16 = source.utf16
        let totalUTF16 = utf16.count
        let clampedOffset = max(0, min(insertionPointUTF16Offset, totalUTF16))

        guard clampedOffset > 0 else { return "" }

        guard let caretIndex = utf16.index(
            utf16.startIndex,
            offsetBy: clampedOffset,
            limitedBy: utf16.endIndex
        ),
        let caretStringIndex = caretIndex.samePosition(in: source) else {
            return ""
        }

        // Walk backwards from the caret to find the start of the current line.
        var lineStart = caretStringIndex
        while lineStart > source.startIndex {
            let previous = source.index(before: lineStart)
            if source[previous] == "\n" {
                break
            }
            lineStart = previous
        }

        // Collect the literal leading whitespace of the current line. Stops at
        // the caret so a caret sitting inside leading whitespace only copies
        // what precedes it.
        var leading = ""
        var cursor = lineStart
        while cursor < caretStringIndex {
            let ch = source[cursor]
            if ch == " " || ch == "\t" {
                leading.append(ch)
                cursor = source.index(after: cursor)
            } else {
                break
            }
        }

        // If the character immediately before the caret is `{`, deepen the
        // indent by one level (4 spaces). Matches Xcode's default behavior.
        // Note: no lexer context — a '{' inside a string literal or comment
        // will trigger the extra indent. Accepted limitation per task spec.
        let prevIndex = source.index(before: caretStringIndex)
        if source[prevIndex] == "{" {
            leading.append("    ")
        }

        return leading
    }
}
