---
dependencies: [04-wire-sttextview, 05-syntax-highlighting, 07-sourcekit-diagnostics-service]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/15
---

# Wire SourceKit Diagnostics to Plugin-Annotations

## Objective

Connect `SourceKitDiagnosticsService` to the editor so that errors and warnings appear as inline annotations in the STTextView gutter and/or underlines as the user types, with a ~300ms debounce after the last keystroke.

## Acceptance Criteria

- [ ] Typing a syntax or type error in the editor causes an inline annotation to appear after ~300ms of inactivity
- [ ] Fixing the error causes the annotation to disappear on the next diagnostic update
- [ ] Annotations show the error message text (truncated if needed) beside the relevant line
- [ ] Errors and warnings are visually distinct (e.g. red vs yellow)
- [ ] The diagnostics request is cancelled and restarted if the user types again before it completes (no stale annotations from an earlier version of the source)
- [ ] App builds with zero warnings

## Implementation Notes

Wire up in `EditorPanel` (or its representable wrapper):

1. Observe text changes from STTextView
2. Debounce with a 300ms `Task.sleep` — cancel the previous task on each new change
3. Call `SourceKitDiagnosticsService.diagnostics(for:)` with the current source
4. Translate `[SwiftDiagnostic]` into the annotation model that Plugin-Annotations expects (check the plugin's API for the exact type)
5. Apply annotations to the STTextView plugin

Use Swift structured concurrency (`Task`, `@MainActor`) for the debounce — avoid `DispatchWorkItem` or `Timer`. A `@State var diagnosticsTask: Task<Void, Never>?` in the view or coordinator is the right pattern: cancel the previous task, then assign a new one on each text change.

## PR

https://github.com/natikgadzhi/quick-icons/pull/15
