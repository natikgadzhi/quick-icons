---
dependencies: [42-extract-editor-view-model]
status: backlog
---

# Replace NotificationCenter Command Bus with Model Method Calls

## Objective

Menu commands (Open, Build, Export, Toggle Invisibles, Zoom In/Out/Reset)
currently dispatch via `NotificationCenter.default` — seven notification
names, with `EditorView` subscribing to each via `.onReceive`. Untyped,
untestable, invisible control flow.

Once task 42 lands, `EditorViewModel` owns all the state and actions. Route
menu commands by binding `@FocusedValue` to the model and having each
`Commands`-scene call model methods directly.

## Acceptance Criteria

- [ ] All seven notification-based menu commands call `EditorViewModel`
      methods directly via `@FocusedValue(\.editorViewModel)`.
- [ ] `NotificationCenter` names defined for these commands are deleted.
- [ ] `EditorView.onReceive(…)` subscriptions for these notifications are
      deleted.
- [ ] Menu → action flow still works end-to-end (open, build, export,
      zoom, invisibles toggle).
- [ ] Zero-warning build; tests pass.

## Notes

- `BuildExportCommands` and `ViewMenuCommands` already exist. They need a
  `@FocusedValue` reference to the model.
- The model is published via `focusedValue(\.editorViewModel, model)` on
  `EditorView` (or wherever the model lives).
- Size: S-M.
