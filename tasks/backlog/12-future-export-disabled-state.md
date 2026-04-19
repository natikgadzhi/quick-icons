---
dependencies: [11-wire-export-button]
status: backlog
---

# [Future] Export Button Disabled State

## Objective

Disable the Export button in the toolbar when no icon has been successfully compiled yet, and re-enable it after a successful compile. This prevents the confusing error state from task 11 where the user exports before compiling.

## Acceptance Criteria

- [ ] Export button is disabled on first launch (no compiled icon)
- [ ] Export button becomes enabled after a successful compile
- [ ] Export button becomes disabled again if the source changes after the last compile (compiled output is stale)
- [ ] Visual state matches macOS conventions (dimmed button, non-interactive)

## Notes

This is intentionally deferred — it is a polish task. The app works correctly without it (task 11 handles the pre-compile export attempt with an error message). Implement this when the core editor loop is stable.

Track `@State private var hasCompiledIcon = false` in `EditorView`. Set to `true` on successful compile, `false` when `sourceCode` changes after a compile.
