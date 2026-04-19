---
dependencies: []
status: backlog
---

# Add SPM Dependencies

## Objective

Add all third-party Swift packages needed for the live icon editor feature to the Xcode project via Swift Package Manager. These packages are prerequisites for all editor UI and diagnostics tasks.

## Acceptance Criteria

- [ ] STTextView is added and the app builds with it linked
- [ ] Plugin-Neon (STTextView syntax highlighting plugin) is added
- [ ] Plugin-Annotations (STTextView inline error annotation plugin) is added
- [ ] SourceKittenFramework is added and the app builds with it linked
- [ ] `xcodebuild build` passes with zero warnings after adding all packages

## Packages to Add

| Package | URL | Notes |
|---------|-----|-------|
| STTextView | `https://github.com/krzyzanowskim/STTextView` | Core text editor component |
| STTextView-Plugin-Neon | `https://github.com/krzyzanowskim/STTextView-Plugin-Neon` | Tree-sitter syntax highlighting |
| STTextView-Plugin-Annotations | Look for it in the STTextView org or the same author | Inline error/warning annotations |
| SourceKittenFramework | `https://github.com/jpsim/SourceKitten` | SourceKit wrapper for diagnostics |

## Notes

- Add packages to the `QuickIcons` target only (not the test targets unless needed)
- Confirm the exact package URLs and available products by checking each repo before adding
- STTextView targets macOS 14+; verify it is compatible with our macOS 26.4 deployment target
- SourceKittenFramework links against `sourcekitd.framework` — verify this is available on macOS without special setup
- Do not import these packages anywhere yet; this task is setup only
