---
dependencies: []
status: backlog
---

# Enable Free STTextView Polish Knobs

## Objective

STTextView ships several appearance and behavior knobs we're not using. Turn
them on in one pass — each is low-risk and the cumulative effect is real polish.

## Acceptance Criteria

- [ ] Line-height: paragraph style with `lineHeightMultiple = 1.2` applied to
      `textView.defaultParagraphStyle` (or via typing attributes).
- [ ] Gutter separator visible between line numbers and text.
- [ ] Gutter selected-line highlight matching the editor's current-line highlight.
- [ ] `textView.gutterView?.areMarkersEnabled = true` (prepares for later
      breakpoint-style markers — no actual markers added yet).
- [ ] `textView.isIncrementalSearchingEnabled = true`.
- [ ] `textView.usesFontPanel = false` (we don't want Format → Font showing up).
- [ ] Menu item (View → Show Invisible Characters) toggling
      `textView.showsInvisibleCharacters`. Default off.
- [ ] Zero-warning build; tests pass.

## Notes

- All changes in `QuickIcons/Views/STTextViewRepresentable.swift` except the
  menu item, which goes in `QuickIconsApp.swift` alongside the existing
  commands. Use the same `Notification.Name` + `.onReceive` pattern
  established by task 18/24.
- The menu command needs a `@FocusedValue` for the current state so the menu
  item can show a checkmark. OK to add a `showsInvisibles` FocusedValue mirror
  to EditorView's @State.
- Size: S (half-day).

## Out of Scope

- Wiring actual breakpoint/error markers (separate task).
- Font picker UI.
