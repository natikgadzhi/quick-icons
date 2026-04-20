---
dependencies: [05-syntax-highlighting, 15-xcode-color-theme]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/49
---

# Bold Font Weights for Xcode-style Syntax Highlighting

## Objective

Match Xcode's editor typography: keywords (and any other token classes Xcode
emphasizes) render in a bolder weight of the monospaced font, not just a
different color. Today everything is `.regular`.

## Acceptance Criteria

- [ ] Swift keywords (`func`, `let`, `var`, `if`, `struct`, `import`, etc.)
      render in a bolder weight, matching Xcode's default editor appearance.
- [ ] Investigate which other token classes Xcode emphasizes with weight
      (types? attributes? `self`?) and match those too. Document the decision
      in the PR body.
- [ ] Non-emphasized tokens stay at the current regular weight.
- [ ] Works in both light and dark appearance (weight is independent of
      appearance, but the theme still needs to carry the attribute).
- [ ] Line height / gutter alignment unaffected (bold glyphs don't shift the
      baseline).
- [ ] Zero-warning build; tests pass.

## Notes

- Extend `Theme.xcode` (the theme used by `NeonPlugin`) to attach a
  `NSFont` attribute with `.semibold` or `.bold` weight to the relevant
  capture classes. Plugin-Neon applies NSAttributedString attributes from the
  theme — adding `.font` alongside `.foregroundColor` should Just Work.
- Check `SourcePackages/checkouts/STPluginNeon` (or the vendored theme file)
  for the current `Theme.xcode` definition — that's the shortest path to
  verify the exact capture names (e.g. `@keyword`, `@type.builtin`).
- Prefer `NSFont.monospacedSystemFont(ofSize:weight: .semibold)` over
  `NSFontManager.convert(...toHaveTrait: .bold)` — the former keeps the
  glyph metrics consistent with the regular-weight font.
- Size: S (~half day).

## Out of Scope

- Italic weights / other trait variants.
- User-configurable syntax theming.
- Changing the base font family.
