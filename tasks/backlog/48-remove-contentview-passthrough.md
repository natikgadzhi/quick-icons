---
dependencies: [42-extract-editor-view-model]
status: backlog
---

# Remove ContentView No-op Pass-through

## Objective

`QuickIcons/Views/ContentView.swift` just forwards to `EditorView()`. Either
delete it (and have `AppRouterView` or `QuickIconsApp` instantiate
`EditorView` directly), or repurpose it as the DI site where
`EditorViewModel` is constructed and passed down.

## Acceptance Criteria

- [ ] `ContentView` is either deleted (and callers updated) or has a clear,
      non-trivial purpose (e.g. constructing the model).
- [ ] Zero-warning build; tests pass.

## Notes

- Prefer deletion if task 42 already places model construction at
  `QuickIconsApp` or `AppRouterView`.
- Size: XS.
