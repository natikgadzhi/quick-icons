---
dependencies: []
status: backlog
---

# Fix SwiftCompilerService Main-Actor UI Freeze

## Objective

`SwiftCompilerService.runProcess` (`QuickIcons/Services/SwiftCompilerService.swift:155`)
calls `process.waitUntilExit()` synchronously inside `withCheckedContinuation`.
Because the service is `@MainActor`, that continuation body runs on the main
actor's executor — freezing the UI for the full `swiftc` compile duration
(seconds). Same pattern in `ToolchainAvailabilityService.defaultProcessRunner`.

## Acceptance Criteria

- [ ] `runProcess` moves the blocking `waitUntilExit()` off the main thread.
- [ ] `ToolchainAvailabilityService.defaultProcessRunner` likewise.
- [ ] Manual verification: Build button press does not freeze unrelated UI
      (e.g. live-typed chars still echo during a multi-second compile).
- [ ] Existing tests still pass; add a unit test if one can meaningfully
      exercise the concurrency behavior (optional — this is primarily an
      executor-placement fix).
- [ ] Zero-warning build.

## Notes

- Simplest fix: wrap the Process setup + `waitUntilExit()` inside the
  continuation in `DispatchQueue.global(qos: .userInitiated).async { … }` so
  the continuation resumes from a background queue.
- Alternative: convert `SwiftCompilerService` from `@MainActor final class` to
  `actor`. Larger blast radius — defer unless needed.
- Size: S.
