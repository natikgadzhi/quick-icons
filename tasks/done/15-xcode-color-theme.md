---
dependencies: [05-syntax-highlighting]
status: backlog
---

# Xcode Color Theme for Syntax Highlighting

## Objective

Replace the default Plugin-Neon `Theme.default` with a custom theme that mirrors Xcode's stock "Default (Light)" and "Default (Dark)" syntax color schemes. The theme should switch automatically with the system appearance so the editor looks at home on both light and dark macOS.

## Background

Task 05 wired Plugin-Neon's `Theme.default`, which uses appearance-aware `NSColor` assets from the plugin's own catalog. The result is functional but visually different from Xcode — users editing SwiftUI icons in this app will have a better mental model if the coloring matches the Xcode editor they already know.

## Acceptance Criteria

- [ ] A `XcodeColorTheme` (or similarly named type) implements Plugin-Neon's `Theme` protocol (or equivalent) with Xcode's canonical token colors for: keywords, types, strings, numbers, comments, identifiers, operators, and punctuation
- [ ] Light variant colors match Xcode "Default (Light)" within reasonable eyeball tolerance
- [ ] Dark variant colors match Xcode "Default (Dark)" within reasonable eyeball tolerance
- [ ] The theme switches automatically when the system appearance changes — no restart required
- [ ] Applied in `STTextViewRepresentable` in place of `Theme.default`
- [ ] App builds with zero warnings

## Reference Colors (approximate, from Xcode 26)

| Token | Light | Dark |
|-------|-------|------|
| Keyword | `#AD3DA4` | `#FF7AB2` |
| Type | `#703DAF` | `#D9B9FF` |
| String | `#D12F1B` | `#FF8170` |
| Number | `#272AD8` | `#D9C97C` |
| Comment | `#707F8C` | `#7F8C98` |
| Identifier | `#000000` | `#FFFFFF` |
| Operator/Punctuation | `#000000` | `#FFFFFF` |

Pick colors via Xcode's own theme files as ground truth: `~/Library/Developer/Xcode/UserData/FontAndColorThemes/` (user-customized) or the stock themes shipped with Xcode.

## Notes

- Use `NSColor(name:dynamicProvider:)` to make a single color value that resolves differently per appearance — this avoids maintaining two separate theme dictionaries.
- Plugin-Neon's `Theme` exposes a mapping of semantic token kinds to colors. Inspect `STTextView-Plugin-Neon` sources in `~/Library/Developer/Xcode/DerivedData/QuickIcons-*/SourcePackages/checkouts/` to see the exact protocol shape before implementing.
- Gutter background and line-number color should also be adjusted to match Xcode's editor gutter for a cohesive look.
