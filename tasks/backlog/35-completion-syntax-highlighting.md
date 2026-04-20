---
dependencies: [27-sourcekit-completions]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/50
---

# Syntax-Highlighted Completion Items

## Objective

Completion list currently renders every item in a single color. Match Xcode:
type names in one color, keywords in another, parameter names distinct,
identifiers neutral. Use the same Xcode palette already resolved for the
editor (`Theme.xcode`) so light/dark mode stays consistent.

## Acceptance Criteria

- [ ] Completion rows display multi-color text: kind-name, parameter names,
      and return type each colored per the Xcode theme.
- [ ] Works in both light and dark appearance.
- [ ] Falls back to plain text if SourceKit doesn't supply structured
      annotations.
- [ ] Zero-warning build; tests pass.

## Notes

- SourceKit's codecomplete response includes a `key.sourcetext` plus a
  `key.description` and, importantly, `key.annotated_typename` /
  `key.annotated_decl` fields that are XML-like strings with tagged spans
  (e.g. `<Type>Int</Type>`). Parse those to produce
  `NSAttributedString` with per-span foreground colors from `Theme.xcode`.
- The `SwiftCompletionItem` model (in
  `QuickIcons/Services/SourceKitCompletionService.swift`) probably only
  exposes `displayText: String` today — extend to carry
  `displayAttributed: NSAttributedString` OR the structured components.
- `SwiftCompletionListItem: STCompletionItem` in
  `QuickIcons/Views/SwiftCompletionItem+STCompletionItem.swift` returns a
  `label` — check if STTextView supports `NSAttributedString` labels; if not,
  vend a custom row view.
- Check STTextView's `STCompletion*` APIs in
  `SourcePackages/checkouts/STTextView/` for the label type and any custom
  row-view hook.
- Keep color sourcing via the existing `Theme.xcode` appearance provider —
  don't duplicate color logic.
- Size: S-M.

## Out of Scope

- Icons for kinds (that's in task 27 stage 3 backlog — keep them separate).
- Fuzzy-match highlight (bolding the matched substring).
