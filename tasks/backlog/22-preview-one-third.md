---
dependencies: []
status: backlog
---

# Preview Pane: One-Third Default Width

## Objective

Fix the default split ratio in `EditorView` so the preview pane occupies ~1/3 of the window width (not ~1/2 as today). The editor panel takes the remaining ~2/3.

Earlier task 10 used `idealWidth: 600` on the editor side and `idealWidth: 300` on the preview side, expecting HSplitView to honor that ratio. In practice `HSplitView` treats `idealWidth` as a soft hint and lands on a 50/50 split; the user confirmed this regressed / never landed correctly.

## Acceptance Criteria

- [ ] On first launch at the default window width (currently `minWidth: 800`), the preview pane is visibly ~1/3 of the window.
- [ ] The user can still drag the splitter in either direction.
- [ ] Resizing the window preserves the roughly 2:1 editor:preview ratio (or at least doesn't shrink the preview to a sliver).
- [ ] Zero-warning build; tests pass.

## Notes

- `HSplitView` in SwiftUI on macOS doesn't expose a direct "split at 2/3" API. Practical options:
  - Set `minWidth` and `idealWidth` on both panels so the preview can't collapse below, say, 280 and the editor has a stronger ideal (`idealWidth: 720` editor, `idealWidth: 360` preview, with a larger default window `minWidth: 1080`). Verify the actual rendered ratio by running the app.
  - If `HSplitView` continues to ignore the hint, drop to `GeometryReader` + explicit `.frame(width: proxy.size.width * 2/3)` on the editor panel (or `* 1/3` on the preview). Keep a draggable seam using an `NSSplitView`-backed representable only if SwiftUI can't be convinced — prefer SwiftUI first.
- Bump the window's `minWidth` if needed so 2/3 of the window is still comfortably wide for code.

## Out of Scope

- Persisting the split position across launches.
- Custom splitter chrome.
