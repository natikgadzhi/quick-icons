---
dependencies: [29-gutter-error-markers]
status: backlog
---

# Error Markers: Shape Around Line Number (Xcode-style)

## Objective

The current gutter error markers (red filled dot) cover the line-number text
because the gutter isn't wide enough to host both. Switch to Xcode's
affordance: a colored rounded-rectangle / capsule *behind* the line number,
with the line-number glyphs rendered in white on top. Warnings use orange,
errors red, notes grey. No separate gutter column.

## Acceptance Criteria

- [ ] On a line with a diagnostic, the line number is drawn in white on a
      filled red/orange/grey rounded rectangle (approx. capsule-shaped), sized
      to hug the line-number text with a small horizontal inset.
- [ ] Line numbers without diagnostics render as today (normal gutter text).
- [ ] Gutter width does not need to expand to accommodate the marker.
- [ ] Severity colors: error → red, warning → orange, note → grey (matches
      existing `DiagnosticMarkerView` palette).
- [ ] Multiple-diagnostics-per-line dedup still uses most-severe-wins (logic
      already in `mostSevereByLine`).
- [ ] Updates reactively on re-compile / re-diagnose, like today.
- [ ] Zero-warning build; tests pass.

## Notes

- Current implementation: `DiagnosticMarkerView` is a small `NSView` with a
  `draw(_:)` that fills a circle. It's installed via
  `gutterView.addMarker(STGutterMarker(...))` in
  `STTextViewRepresentable.swift:applyGutterMarkers`. The marker is positioned
  beside the line number, hence the collision.
- Approach: the custom marker view needs to be sized to span the full
  line-number glyph area. It should draw the colored capsule background AND
  the line-number text in white on top, replacing the default line-number
  rendering for that line.
- Check `SourcePackages/checkouts/STTextView/Sources/STTextViewAppKit/Gutter/STGutterView.swift` to see how default
  line-number text is drawn, and how a marker view is laid over (or beside)
  that rendering. We may need to:
  - (a) provide a wider marker view that covers the default text, or
  - (b) hook into whatever API draws the line number per line, or
  - (c) set `textColor` on the marker view to white and have STTextView draw
        the number on top of our background.
- If the default STTextView marker API is too restrictive (doesn't let us
  replace the line-number rendering on that row), consider filing an upstream
  feature request and falling back to a wider gutter with a separate marker
  column.
- Size: S–M depending on STGutterView flexibility.

## Out of Scope

- Breakpoint-style solid triangle markers.
- Clicking the marker to reveal a popover — future task.
