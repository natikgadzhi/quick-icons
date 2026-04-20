---
dependencies: []
status: backlog
---

# Lazy-async SDK Path Resolution in SourceKit Services

## Objective

`SourceKitDiagnosticsService.cachedSDKPath` (line 13) and
`SourceKittenRunner.cachedSDKPath` (in `SourceKitCompletionService.swift:200`)
are `static let` that synchronously run `xcrun --show-sdk-path` via
`Process().waitUntilExit()` at first type access. Under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` that's on the main thread, on the
first keystroke — visible as a stutter.

`SwiftCompilerService` already does this the right way (task 40 will keep
improving it). Apply the same pattern here.

## Acceptance Criteria

- [ ] `cachedSDKPath` in both services is resolved inside an async call
      (first invocation of `diagnostics(for:)` / `run(source:offset:)`), not
      at type-init time.
- [ ] The resolved path is cached after first success so subsequent calls
      are free.
- [ ] Concurrent first-calls don't each spawn `xcrun`. Either serialize the
      resolve, or accept one duplicate (document the choice).
- [ ] Zero-warning build; existing tests pass.

## Notes

- Cleanest: use `SwiftCompilerService`'s approach — store `private var
  sdkPath: String?`, populate on first `compile` via `Task.detached`. Wrap
  in a small `SDKPathCache` actor if both services want to share it.
- Don't break deterministic test injection: if tests inject a fake path
  today, keep the seam.
- Size: S.
