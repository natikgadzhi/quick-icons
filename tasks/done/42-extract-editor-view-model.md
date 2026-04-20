---
dependencies: []
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/60
---

# Extract EditorViewModel as @Observable

## Objective

`EditorView` (`QuickIcons/Views/EditorView.swift:55-219`) owns: editor state
(`sourceCode`, `fontSize`, `showsInvisibles`), the compile lifecycle
(`isCompiling`, `compiledDylibURL`, `compileError`, `compiledImage`,
`hasCompiledIcon`), the export lifecycle (`exportMessage`), direct
`dlopen`/`dlsym` in `export()`, and seven `NotificationCenter` subscriptions.
That's 3+ responsibilities in one view. It also blocks proper DI: services
are `let = Service()` at the view, so tests can't mock them.

Extract an `@Observable EditorViewModel` that owns the compile/export
lifecycle and receives services via its init. `EditorView` becomes a
structural view.

## Acceptance Criteria

- [ ] New `EditorViewModel.swift` under `QuickIcons/Views/` (or a new
      `ViewModels/` dir) that's `@Observable` and owns:
      `sourceCode`, `fontSize`, `showsInvisibles`, `isCompiling`,
      `compiledDylibURL`, `compileError`, `compiledImage`, `hasCompiledIcon`,
      `exportMessage`, and the `compile()` / `export()` methods.
- [ ] `EditorView` holds a single `@State var model = EditorViewModel()` (or
      `@Bindable` on a model passed in) and delegates all actions.
- [ ] All three services (`SwiftCompilerService`, `IconPreviewService`,
      `IconExportService`) are stored on the model and accept an init
      parameter with a reasonable default — so tests can inject fakes.
- [ ] All existing functionality unchanged: compile works, export works,
      preview renders, diagnostics still flow.
- [ ] Zero-warning build; tests pass.

## Notes

- Out of scope: replacing `NotificationCenter` command bus — task 43.
- Out of scope: eliminating `dlopen` duplication — task 45.
- This task is ONLY the model extraction + DI surface.
- Protocols are optional for now — concrete types are fine as long as the
  initializer accepts them (tests can subclass if needed).
- Size: M.
