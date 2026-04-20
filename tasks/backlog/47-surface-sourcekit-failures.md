---
dependencies: []
status: backlog
---

# Surface SourceKit Failures to UI

## Objective

`SourceKitDiagnosticsService` has a catch-all `catch { return [] }` at
`SourceKitDiagnosticsService.swift:30-35`. A sourcekitd crash, timeout, or
malformed response looks identical to "no diagnostics" from the UI's
perspective. Users can't tell whether their code is clean or whether tools
are broken.

## Acceptance Criteria

- [ ] `diagnostics(for:)` distinguishes success from failure (e.g. returns
      `Result<[SwiftDiagnostic], Error>` or an enum with `.unavailable`).
- [ ] The caller (coordinator / model) surfaces a subtle "diagnostics
      unavailable" affordance when the result is a failure — gutter icon,
      status-bar message, or similar.
- [ ] Clean code continues to show zero markers.
- [ ] Zero-warning build; tests pass.

## Notes

- Keep the change narrow — this is about signal, not a redesign.
- Consider the same for `SourceKitCompletionService` if the pattern is
  mirrored there.
- Size: S.
