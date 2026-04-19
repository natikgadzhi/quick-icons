---
dependencies: [01-add-spm-dependencies, 02-basic-editor-ui-layout]
status: backlog
---

# Wire STTextView into EditorPanel

## Objective

Replace the `TextEditor` placeholder in `EditorPanel` with `STTextView`, the rich AppKit-based text editor that supports syntax highlighting and annotation plugins. This task wires up the view binding only — plugins are added in tasks 05 and 08.

## Acceptance Criteria

- [ ] `EditorPanel` uses `STTextView` instead of `TextEditor`
- [ ] The `sourceCode: Binding<String>` passed into `EditorPanel` stays in sync with the text in the editor (edits are reflected back)
- [ ] The editor uses a monospaced font (SF Mono or system monospaced, 13pt)
- [ ] Line numbers are visible in the gutter
- [ ] The editor has standard text editing behaviour: undo/redo, copy/paste, select all
- [ ] App builds and the editor is functional when run

## Notes

STTextView is an AppKit component; wrap it in `NSViewRepresentable` or use its provided SwiftUI wrapper if one is available in the package. Check the STTextView README for the recommended SwiftUI integration pattern.

The coordinator/delegate for the SwiftUI bridge should update the `Binding<String>` on every text change via `textDidChange` or the equivalent STTextView delegate callback.

Do not configure any plugins (Neon, Annotations) in this task — leave plugin setup points as empty arrays or commented stubs so tasks 05 and 08 can add them cleanly.
