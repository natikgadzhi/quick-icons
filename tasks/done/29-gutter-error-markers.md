---
dependencies: [07-sourcekit-diagnostics-service, 26-sttextview-free-knobs]
status: backlog
---

# Gutter Error Markers (Breakpoint-style Dots)

## Objective

Show red dot markers in the gutter next to lines with SourceKit errors, in
addition to the existing inline annotations. Matches Xcode's breakpoint/error
affordance.

## Acceptance Criteria

- [ ] Red circle marker appears in the gutter on lines with errors from
      `SourceKitDiagnosticsService`.
- [ ] Yellow/orange marker for warnings (if we surface warnings distinctly — OK
      to skip if we only produce error-level diagnostics today).
- [ ] Markers update reactively as the user edits and re-compiles.
- [ ] Clicking a marker does not need to do anything specific (future: show
      quick-fix menu) — but must not crash.
- [ ] Zero-warning build; tests pass.

## Notes

- Depends on task 26 enabling `gutterView.areMarkersEnabled = true`.
- Use `STGutterMarker` — see
  `SourcePackages/checkouts/STTextView/Sources/STTextViewAppKit/Gutter/*`.
- Wire into the existing diagnostics pipeline in
  `QuickIcons/Services/SourceKitDiagnosticsService.swift` consumers (the view
  that already renders inline annotations).
- Size: M (~2 days).

## Out of Scope

- Quick-fix menu on marker click.
- Custom marker shapes beyond the default dot.

## PR

https://github.com/natikgadzhi/quick-icons/pull/40
