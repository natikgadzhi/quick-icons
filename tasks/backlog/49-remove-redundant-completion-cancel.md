---
dependencies: []
status: backlog
---

# Remove Redundant completionTask Cancel

## Objective

In `STTextViewRepresentable.Coordinator.textViewDidChangeText`
(`STTextViewRepresentable.swift:281-282`):

```swift
completionTask?.cancel()
textView.complete(self)
```

`textView.complete(self)` triggers STTextView to call the async delegate
`textView(_:completionItemsAtLocation:)` which already cancels and replaces
`completionTask`. The outer cancel is a no-op today and sets up a subtle
race if STTextView ever schedules the delegate call on a delay.

## Acceptance Criteria

- [ ] Remove the redundant `completionTask?.cancel()` in
      `textViewDidChangeText`.
- [ ] Ensure `deinit` (or the equivalent teardown point) still cancels any
      in-flight `completionTask` — add if missing.
- [ ] Completion still works end-to-end.
- [ ] Zero-warning build; tests pass.

## Notes

- Trivial diff. Document the cancellation ownership with a short comment
  only if non-obvious.
- Size: XS.
