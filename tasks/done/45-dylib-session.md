---
dependencies: []
status: backlog
---

# Consolidate dlopen into a Shared DylibSession

## Objective

`IconPreviewService.render` (`IconPreviewService.swift:29-44`) and
`EditorView.export()` (`EditorView.swift:186-202`) each independently
`dlopen` the same compiled dylib with `RTLD_LOCAL`. Two concurrent handles
to the same path can return a stale symbol after rebuild. Views also
shouldn't contain `unsafeBitCast` pointer math.

Introduce a `DylibSession` value/actor owning the handle. Preview and
export both acquire a session for the current compile; the session closes
the previous handle before opening a new one for the same path, and
exposes a typed `makeView: (CGFloat) -> AnyView` factory.

## Acceptance Criteria

- [ ] New `DylibSession.swift` under `QuickIcons/Services/` exposes a
      `loadIcon(at: URL) -> IconFactory` (or similar typed surface) and
      ensures only one live handle exists per path.
- [ ] `IconPreviewService.render` uses `DylibSession` (no direct `dlopen`).
- [ ] `EditorView.export()` — or `EditorViewModel.export()` after task 42 —
      uses `DylibSession` (no direct `dlopen` / `dlsym` / `unsafeBitCast`).
- [ ] Compile → preview → export cycle works as before. Rebuild replaces
      the session cleanly (no stale symbol).
- [ ] Zero-warning build; tests pass.

## Notes

- Independent of task 42 — can land in either order. Coordinate with
  whichever worker is touching `EditorView` / `EditorViewModel`.
- Size: S-M.


## PR
https://github.com/natikgadzhi/quick-icons/pull/57
