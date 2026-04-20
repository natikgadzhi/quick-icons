---
dependencies: [19-preview-padding]
status: in-progress
---

# Preview Panel: Stable Size Across States

## Objective

The right-side preview panel should keep a constant width when the user hits
Build. Today the panel shifts/grows because the compiling state, placeholder
state, and image state have different intrinsic sizes.

## Acceptance Criteria

- [ ] Pressing Build does not resize the preview panel.
- [ ] Same is true for switching between placeholder → compiling → image →
      error states.
- [ ] Zero-warning build; tests pass.

## Notes

- Look at `QuickIcons/Views/PreviewPanel.swift` — the different state views
  (placeholder, `ProgressView`, image, error) likely have different intrinsic
  content sizes. Wrap them in a container with a fixed or `.infinity`
  frame, or set a `minHeight`/`idealHeight` so the layout doesn't snap.
- Size: XS.

## Out of Scope

- Animating state transitions.
