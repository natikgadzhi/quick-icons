---
dependencies: [25-expand-xcode-theme]
status: backlog
---

# Load Plugin-Neon locals.scm for Scope-aware Highlighting

## Objective

Plugin-Neon ships `locals.scm` for Swift but `Coordinator.swift:81` only loads
`highlightQueryURL`. Loading `localsQueryURL` enables scope-aware
disambiguation (local var vs. type in a parameter list, project property vs.
global), which brings our highlighting closer to Xcode's.

## Acceptance Criteria

- [ ] `locals.scm` is loaded alongside `highlights.scm`.
- [ ] `self`, `super`, and locally-scoped identifiers color distinctly from
      project-level properties.
- [ ] Visual regression spot-check: screenshots of 2-3 representative icon
      source files before/after show noticeable improvement with no new
      miscoloring.
- [ ] Zero-warning build; tests pass.

## Notes

- Two implementation options:
  1. **Vendor a thin `LocalNeonPlugin` in `QuickIcons/`** that wires
     `TreeSitterClient` directly with both queries. Keeps upstream Plugin-Neon
     untouched for UIKit/iOS demos.
  2. **PR upstream** to Plugin-Neon. Slower feedback loop; depends on
     maintainer merge velocity.
- Option 1 is preferred — we get faster iteration and can drop to the upstream
  plugin if they land the same fix later.
- Size: M (2–3 days).
- Reference: `docs/sttextview-audit.md` §2.2.

## Out of Scope

- Injections (`injections.scm`) — grammar vendored without it.
- Grammar upgrade to a newer tree-sitter-swift version.
