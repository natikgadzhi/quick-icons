---
dependencies: [15-xcode-color-theme]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/35
---

# Expand XcodeColorTheme to all 28 Swift Captures

## Objective

Our `XcodeColorTheme` maps only 20 of the 28 tree-sitter-swift capture scopes.
Worse, `method` and `function.call` are mapped to the plain foreground, which
explains most of the "flat" feel compared to Xcode. This task expands the theme
to cover every capture and retints the function-call scopes to Xcode's blue.

## Acceptance Criteria

- [ ] `Theme.Colors.xcode` (or the equivalent theme dictionary) has entries for
      all 28 captures in
      `SourcePackages/checkouts/STTextView-Plugin-Neon/Sources/TreeSitterSwiftQueries/highlights.scm`.
- [ ] Missing captures added (at minimum): `conditional`, `repeat`,
      `keyword.operator`, `function.macro`, `property`, `variable.builtin`,
      `float`, `string.regex`.
- [ ] `method` and `function.call` retinted to Xcode's function-call blue
      (matches Xcode Default Dark / Default Light appearance).
- [ ] Light and dark appearances each have a color for every capture.
- [ ] No new tests required — pure data change — but existing build/tests stay
      green with zero warnings.

## Notes

- Reference colors: Xcode Default (Light) and Default (Dark) themes — pull the
  hex values from Xcode's Preferences → Themes.
- Authoritative capture list:
  `SourcePackages/checkouts/STTextView-Plugin-Neon/Sources/TreeSitterSwiftQueries/highlights.scm`.
- Size: S (half-day). Pure data change inside `Theme.Colors.xcode` in
  `QuickIcons/Views/XcodeColorTheme.swift`.

## Out of Scope

- Loading `locals.scm` (separate task).
- Fixing `clearStyle` asymmetry (separate task).
- Adding new themes beyond Xcode.
