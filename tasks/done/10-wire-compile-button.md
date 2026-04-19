---
dependencies: [02-basic-editor-ui-layout, 06-swift-compiler-service, 09-icon-preview-service]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/14
---

# Wire Compile Button to Compiler and Preview Panel

## Objective

Connect the Compile button in `EditorView`'s toolbar to `SwiftCompilerService` and `IconPreviewService`. A successful compile updates the preview panel with the rendered icon. A failed compile shows a compilation error state in the preview panel. This is the core interactive loop of the app.

## Acceptance Criteria

- [ ] Tapping "Compile" triggers compilation of the current editor source
- [ ] While compiling, the button label changes to "Compiling…" and is disabled
- [ ] On success: `PreviewPanel` shows the rendered icon image
- [ ] On failure: `PreviewPanel` shows an error state — a red SF symbol icon and the first error message as text (e.g. "Error on line 14: use of unresolved identifier 'foo'")
- [ ] The previous preview is cleared when a new compile starts (show a progress spinner or dim the old image)
- [ ] The user can compile again immediately after a failed compile
- [ ] App builds with zero warnings

## State in EditorView

```swift
@State private var sourceCode: String = ...
@State private var compiledImage: NSImage?
@State private var compileError: String?
@State private var isCompiling = false
private let compiler = SwiftCompilerService()
private var previewer = IconPreviewService()
```

On compile:
1. Set `isCompiling = true`, clear `compileError`
2. Call `compiler.compile(source: sourceCode)`
3. On `.success(let url)`: call `previewer.render(dylibURL: url, size: 400)`, set `compiledImage`
4. On `.failure(let diagnostics)`: set `compileError` to the first error diagnostic's message
5. Set `isCompiling = false`

## Notes

`PreviewPanel` needs to accept both `image: NSImage?` and `errorMessage: String?`. Update its interface if needed.

The preview render size of 400pt is a good default for the panel — `IconPreviewService` renders at @2x so the actual CGImage is 800×800px, which looks sharp at any panel width.

The compile runs on a background `Task` (via `async`). Use `await MainActor.run` or mark the function `@MainActor` to update state back on the main thread — the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` should make this straightforward.
