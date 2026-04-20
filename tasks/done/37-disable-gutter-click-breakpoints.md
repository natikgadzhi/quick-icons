---
dependencies: [29-gutter-error-markers, 32-error-marker-around-line-number]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/47
---

# Disable Click-to-Add Breakpoint Markers in Gutter

## Objective

Clicking the gutter currently drops a "breakpoint" marker that does nothing —
we don't implement breakpoints or any click action. Users hit it by accident
and get confused. Disable this interaction while keeping programmatic
`addMarker(_:)` working for diagnostics.

## Acceptance Criteria

- [ ] Clicking the gutter (left-click, anywhere) does not add or toggle a
      marker.
- [ ] Diagnostic markers added programmatically from
      `applyGutterMarkers(...)` still render correctly.
- [ ] No regression in scrolling, line-number rendering, or selection.
- [ ] Zero-warning build; tests pass.

## Notes

- Task 26 set `textView.gutterView?.areMarkersEnabled = true` to enable the
  programmatic marker pipeline. That same flag also enables click-to-add.
  Check `SourcePackages/checkouts/STTextView/Sources/STTextViewAppKit/Gutter/STGutterView.swift`
  — look for whether `areMarkersEnabled` splits into separate knobs for
  "programmatic markers" vs "user interaction" (unlikely, but worth a look).
- If the flag is combined, options:
  - (a) Override the click handler by subclassing / swapping the gutter's
        mouse handling — probably too invasive.
  - (b) Install a gesture recognizer on the gutter that eats left-clicks
        before STGutterView sees them.
  - (c) After each `applyGutterMarkers` pass, diff the current gutter
        markers against our `diagnosticMarkerLines` set and remove any that
        aren't ours — effectively immediately undoing any user click.
- Option (c) is simplest and least invasive but flashes the marker for one
  frame. Acceptable UX for now. Track "our" markers with a tagged subclass
  of `DiagnosticMarkerView` so distinguishing ours vs user's is trivial.
- Size: XS.

## Out of Scope

- Implementing real breakpoints.
- Right-click context menu on the gutter.
