---
dependencies: [42-extract-editor-view-model]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/64
---

# Split STTextView Coordinator into Focused Helpers

## Objective

`STTextViewRepresentable.Coordinator` (`STTextViewRepresentable.swift:98-504`)
does: two-way text binding, auto-indent, diagnostics (debounce + gutter
markers + annotations), completions (debounce + placeholder handling +
identifier prefix math), UTF-16↔UTF-8 conversion. Five concerns in one
class. It also instantiates `SourceKitDiagnosticsService` and
`SourceKitCompletionService` inline — untestable.

Split into `DiagnosticsCoordinator` and `CompletionCoordinator` (plain
`@MainActor` helpers, not SwiftUI Coordinators), each accepting an injected
service. Coordinator keeps text binding + auto-indent + delegates the rest.

## Acceptance Criteria

- [ ] `DiagnosticsCoordinator` owns: diagnostics Task, debounce,
      `applyGutterMarkers`, `mostSevereByLine`, gutter marker bookkeeping.
- [ ] `CompletionCoordinator` owns: completion Task, debounce, identifier
      prefix math, placeholder selection, `insertCompletionItem` logic.
- [ ] Both accept their service via init (`SourceKitDiagnosticsService` /
      `SourceKitCompletionService`), and the `Coordinator` passes the ones
      injected at the `EditorViewModel` level — reuse task 42's DI seam.
- [ ] Existing tests still pass. Add tests that exercise the new helpers
      directly with mock services.
- [ ] Zero-warning build.

## Notes

- Auto-indent stays on `Coordinator` — it's tiny and tied to
  `shouldChangeTextIn`.
- UTF-16/UTF-8 helpers live in a shared `TextOffset` enum/namespace used by
  both new coordinators.
- Size: M.
