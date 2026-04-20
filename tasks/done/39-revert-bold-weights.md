---
dependencies: []
status: in-progress
---

# Revert Bold Font Weights to Match Actual Xcode

## Objective

Task 31 bolded several capture classes assuming Xcode emphasizes keywords with
weight. Visual comparison shows Xcode's default themes use `SFMono-Regular`
throughout — emphasis is purely color-based. Revert to `.regular` weight
everywhere.

## Acceptance Criteria

- [ ] All capture classes render in `.regular` weight (monospaced system font).
- [ ] `XcodeBoldCaptures` helper either deleted or collapsed — no capture
      returns bold.
- [ ] Existing tests updated accordingly; zero-warning build; tests pass.

## Notes

- Files: `QuickIcons/Views/XcodeColorTheme.swift`,
  `QuickIconsTests/XcodeBoldCapturesTests.swift`.
- Keep the `Theme.Fonts` builder structure, just drop the bold branching.
