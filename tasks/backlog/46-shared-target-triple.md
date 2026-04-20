---
dependencies: []
status: backlog
---

# Extract Shared Target Triple Constant

## Objective

`arm64-apple-macosx15.0` is hard-coded in three places:
- `SourceKitDiagnosticsService.swift:99`
- `SourceKitCompletionService.swift` (`SourceKittenRunner.buildCompilerArgs`, ~line 257)
- `SwiftCompilerService.swift:92`

Silent breakage on Intel / Rosetta / future OS bumps.

## Acceptance Criteria

- [ ] Single `BuildEnvironment.currentTarget: String` (or similar) defined
      once, preferably computed from `ProcessInfo` when feasible (falls back
      to the hard-coded triple if the runtime detection can't be trusted).
- [ ] All three services consume the shared constant.
- [ ] Zero-warning build; tests pass.

## Notes

- Keep this tiny — one new file, one constant. Don't design a full build-env
  abstraction.
- Size: XS.
