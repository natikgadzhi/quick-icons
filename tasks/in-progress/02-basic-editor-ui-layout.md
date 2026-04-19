---
dependencies: []
status: backlog
---

# Basic Editor UI Layout

## Objective

Replace the current `IconExportView`-based `ContentView` with a new `EditorView` that has the two-panel split layout the live editor will live in: a left code editor panel and a right icon preview panel, with a toolbar containing Compile and Export buttons. This task uses placeholder content — the panels are wired up with real functionality in later tasks.

## Acceptance Criteria

- [ ] `ContentView` now shows `EditorView`
- [ ] `EditorView` is an `HSplitView` with a left panel (min 420pt) and right panel (min 300pt)
- [ ] Left panel (`EditorPanel`) shows a `TextEditor` with pre-populated Swift source code (see Notes)
- [ ] Right panel (`PreviewPanel`) shows an empty state: a centered icon placeholder (SF Symbol `"photo.artframe"` or similar) with the label "Compile to preview"
- [ ] The window toolbar has a "Compile" button (primary action) and an "Export" button
- [ ] Both buttons are present but have no action yet (stubs only — wired in later tasks)
- [ ] The window has a sensible minimum size (e.g. `minWidth: 800, minHeight: 500`)
- [ ] App builds and the layout is visible when run
- [ ] The old `IconExportView.swift` is removed (superseded)

## New Files

- `QuickIcons/Views/EditorView.swift` — root split view + toolbar, owns `@State var sourceCode: String` and `@State var compiledImage: NSImage?`
- `QuickIcons/Views/EditorPanel.swift` — left panel wrapping `TextEditor` (replaced with STTextView in task 04)
- `QuickIcons/Views/PreviewPanel.swift` — right panel showing `NSImage?` or empty state

## Notes

Pre-populate `sourceCode` with the full text of `ScrapesBookIconView.swift` as a starting template. Copy the source text in as a multiline Swift string literal — the user should see real, runnable icon code when they first open the app.

`PreviewPanel` should accept `image: NSImage?`. When `nil`, show the empty state. When non-nil, show the image scaled to fit within the panel (maintaining aspect ratio).

The toolbar Export button should call `NSOpenPanel` and then `IconExportService` (same flow as before) but for now leave the action body empty with a `// TODO` comment.

`ExportableIcon` and `IconExportService` stay in place — they will be reused by the Export button in task 11.
