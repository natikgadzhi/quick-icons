---
dependencies: [06-swift-compiler-service]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/18
---

# App-Level Toolchain Availability Router

## Objective

Add app-level state tracking and a router view that determines, at launch, whether the Swift toolchain needed by `SwiftCompilerService` is actually installed. If `swiftc` is not available, the app must enter a failure state and render a view instructing the user to install the Xcode Command Line Tools (or full Xcode). If available, the app proceeds to `EditorView` as today.

## Background

macOS does not ship with a real Swift compiler. `/usr/bin/swift` and `/usr/bin/swiftc` are stub shims that prompt the user to install Xcode Command Line Tools when invoked. The real compiler is provided by either:

- Xcode.app (full IDE)
- Xcode Command Line Tools (`xcode-select --install`)

`SwiftCompilerService` currently resolves `swiftc` via `xcrun -f swiftc`, which also fails if neither is installed. Without this check, the first compile attempt produces a confusing error; with it, we can show a clear onboarding/recovery view.

## Acceptance Criteria

- [ ] A `ToolchainAvailability` service (or equivalent) exposes an async check that returns whether `swiftc` is usable (e.g. `xcrun -f swiftc` returns a path AND invoking it with `--version` exits 0)
- [ ] An app-level state enum (e.g. `AppState.ready` / `.toolchainMissing` / `.checking`) drives a root router view
- [ ] On launch, the app shows a brief "checking" state, then transitions to either `EditorView` (ready) or a `ToolchainMissingView` (failure)
- [ ] `ToolchainMissingView` explains the problem in plain language and tells the user to run `xcode-select --install` or install Xcode. Include a "Re-check" button that re-runs the availability check (so the user can fix and continue without relaunching)
- [ ] The check is non-blocking — the UI shows immediately; it doesn't freeze the launch
- [ ] Unit test: the availability check returns false when given a deliberately invalid toolchain path (inject the path or refactor to allow that)
- [ ] App builds with zero warnings; all tests pass

## Notes

- The shim at `/usr/bin/swiftc` will *pop a system prompt* to install CLI Tools when invoked without them installed. We should detect the "no real toolchain" state *before* shelling out to `swiftc`, so we don't surprise the user with a system dialog on launch. Using `xcrun -f swiftc` and then verifying `--version` works is a reasonable probe — if `xcrun` itself is missing, that's also a failure signal.
- Keep the "missing" view simple: an SF Symbol (e.g. `"wrench.and.screwdriver"`), a headline, a short paragraph, the exact command to copy (`xcode-select --install`), and a Re-check button.
- The router belongs at the `@main` app struct level (or a top-level view directly under it), replacing the direct `ContentView` → `EditorView` today.
