---
dependencies: [08-wire-annotations, 10-wire-compile-button, 11-wire-export-button]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/38
---

# Simplify Pass Across Services and Views

## Objective

Run the `/simplify` skill over the accumulated code in `QuickIcons/Services/` and `QuickIcons/Views/` to remove unnecessary abstractions, premature error handling, and redundant state introduced during rapid feature development. Focus on the compile → preview → export loop that tasks 06, 09, 10, and 11 built up.

## Acceptance Criteria

- [ ] `/simplify` skill is run over each file in `QuickIcons/Services/` and `QuickIcons/Views/`
- [ ] Redundant state, dead parameters, and unused helpers are removed
- [ ] Comments that only restate the code are dropped; comments explaining *why* are kept
- [ ] Error handling at internal call sites (non-boundary) is tightened — no "just in case" catches
- [ ] Any premature abstractions (protocols with one implementation, wrappers that add no value) are collapsed
- [ ] App still builds with zero warnings; all tests pass
- [ ] The PR description lists each non-trivial simplification so the reviewer can sanity-check semantics are preserved

## Notes

- Run as one focused PR per area if the diff would otherwise be too large — e.g. one PR for Services, one for Views. Small, reviewable PRs beat one sweeping change.
- Do not weaken tests to make simplification easier. If a test has to change, call it out in the PR.
- Keep in mind the CLAUDE.md project rule: "No premature abstraction — build what the task needs, nothing more." This task is the enforcement pass for that rule.
