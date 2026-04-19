---
dependencies: [01-add-spm-dependencies, 04-wire-sttextview]
status: backlog
---

# Swift Syntax Highlighting with Plugin-Neon

## Objective

Add real-time Swift syntax highlighting to the editor using STTextView's Plugin-Neon, which uses tree-sitter for parsing. Highlighting should work offline and apply immediately when the editor loads.

## Acceptance Criteria

- [ ] Swift keywords, types, strings, comments, and numbers are visually distinguished in the editor
- [ ] Highlighting updates as the user types (not just on load)
- [ ] Highlighting uses colors appropriate for the system appearance (light and dark mode)
- [ ] App builds with zero warnings

## Notes

Plugin-Neon uses tree-sitter under the hood. You will need:
1. The `STTextView-Plugin-Neon` package (added in task 01)
2. A tree-sitter Swift grammar — check if one ships with the plugin or needs to be added separately (look for `tree-sitter-swift` or similar)

Wire the plugin into the STTextView setup in `EditorPanel` (or its `NSViewRepresentable` wrapper) — the plugin setup was left as a stub in task 04.

Use a theme that maps to system colors where possible so it looks reasonable in both light and dark mode. A simple theme with distinct colors for keywords, strings, comments, and types is sufficient.
