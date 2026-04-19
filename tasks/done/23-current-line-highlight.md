---
dependencies: []
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/31
---

# Current Line Highlighting (Xcode-style)

## Objective

Highlight the line containing the caret with a subtle background tint, matching Xcode's default editor behavior. The highlight spans the full width of the editor, follows the caret as the user moves, and adapts to light/dark appearance.

## Acceptance Criteria

- [ ] The line containing the insertion point has a subtle background color distinguishing it from other lines.
- [ ] The highlight moves as the caret moves (arrow keys, clicks, after paste, etc.).
- [ ] Highlight color matches Xcode's current-line tint within reasonable eyeball tolerance:
  - Light: ~`#E8F0FE` / a faint blue-grey
  - Dark: a low-opacity white on the dark editor background (~8% white)
- [ ] Uses `NSColor(name:dynamicProvider:)` so the color swaps automatically with system appearance — no restart required.
- [ ] If the selection spans multiple lines, the highlight either tracks all selected lines OR disappears (match Xcode's behavior; document the choice).
- [ ] Zero-warning build; tests pass.

## Notes

- STTextView exposes line-highlight knobs — check the STTextView sources under `~/Library/Developer/Xcode/DerivedData/QuickIcons-*/SourcePackages/checkouts/STTextView/` for the exact property / plugin (`highlightSelectedLine` or similar on `STTextView`).
- If STTextView has a built-in `highlightSelectedLine` property, this is a one-line toggle plus theming. Set the color via `selectedLineHighlightColor` (or the equivalent name — confirm in the source).
- If not, a tiny custom plugin that listens to selection changes and draws a background in the line-fragment area is the fallback.
- Place wiring in `QuickIcons/Views/STTextViewRepresentable.swift` alongside the existing Plugin-Neon / Annotations setup.
- Coordinate with task 21 (STTextView audit) if it lands first — it may surface additional knobs worth enabling in the same PR.

## Out of Scope

- Persisted caret position across launches.
- Gutter line-number highlighting for the active line (a nice-to-have; file as a follow-up if desired).
