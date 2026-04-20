---
dependencies: [22-preview-pane-width]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/42
---

# Preview Pane Default Width — Actual 1/3, Not 1/2

## Objective

Task 22 tried to make the preview pane default to 1/3 of the window, but on
first launch it still renders at ~50/50. Root cause in
`QuickIcons/Views/EditorView.swift` around lines 86–89:

```swift
PreviewPanel(...)
    .frame(
        minWidth: 300,
        idealWidth: proxy.size.width / 3,
        maxWidth: max(proxy.size.width / 2, 300)  // <-- too generous
    )
```

`maxWidth` caps the preview at half the window, and HSplitView's slack
distribution lets it grow to that cap. Tighten the cap so the preview
genuinely stays around 1/3 on a fresh window.

## Acceptance Criteria

- [ ] On a fresh window (default 1080pt wide), the preview pane renders at
      roughly 1/3 (~360pt), NOT half.
- [ ] User can still drag the divider to resize.
- [ ] Minimum preview width stays at 300pt.
- [ ] On a very wide window, preview does not balloon past ~40% of window.
- [ ] Zero-warning build; tests pass.

## Notes

- Tighten the `maxWidth` on the preview frame to `proxy.size.width / 3` (or
  a touch more, e.g. `* 0.4`, but not 0.5). Editor's `maxWidth: .infinity`
  then soaks the remaining slack.
- If HSplitView still ignores the ideal and lands at the minimums sum, try
  also clamping the editor's `idealWidth` more aggressively — but start
  with the preview cap fix; it's the direct cause.
- Do NOT convert to NSSplitView — out of scope. The fix should be one
  numeric tweak.
- Size: XS (~30 min).

## Out of Scope

- Persisting the divider position across launches.
- Converting to NSSplitView.
