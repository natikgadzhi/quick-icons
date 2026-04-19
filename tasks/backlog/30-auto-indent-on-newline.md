---
dependencies: [04-wire-sttextview]
status: backlog
---

# Auto-Indent on Newline

## Objective

When the user presses Return/Enter in the editor, the new line should start at
the indentation level of the previous line (copy leading whitespace), and
optionally add one more indent level after an opening brace `{` or `(`. Avoid
starting every new line at column 0.

## Acceptance Criteria

- [ ] Pressing Return on a line with leading whitespace produces a new line
      with the same leading whitespace.
- [ ] Pressing Return at the end of a line ending in `{` adds one extra indent
      level (4 spaces or one tab — match editor default; 4 spaces is fine).
- [ ] Works for both tab- and space-indented source (inspect the current
      line's whitespace and replicate it literally — do not convert).
- [ ] Does not fight STTextView's built-in newline handling — the inserted
      indentation should arrive in a single edit so undo treats it as one
      operation.
- [ ] Zero-warning build; tests pass.

## Notes

- STTextView forwards commands via `NSTextViewDelegate`-style hooks. Try
  `textView(_:doCommandBy:)` with `#selector(insertNewline(_:))` on the
  Coordinator. Return `true` after inserting the newline + indentation
  manually via `textView.insertText(_:replacementRange:)`.
- Compute leading whitespace from the line containing the current selection's
  start location. Walk backwards from the insertion point to the previous
  newline, capture the whitespace prefix.
- Trim trailing whitespace detection: if the character immediately before the
  insertion point is `{`, append one indent level.
- Keep the logic in the Coordinator of `STTextViewRepresentable.swift` —
  don't introduce a new service for this.
- Size: S (~half day).

## Out of Scope

- Smart outdent on `}` (separate polish task if desired).
- Respecting the user's preferred indent width / tab-vs-space setting.
- Multi-cursor / multi-selection auto-indent (single caret only).
