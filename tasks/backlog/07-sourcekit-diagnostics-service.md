---
dependencies: [01-add-spm-dependencies]
status: backlog
---

# SourceKitDiagnosticsService

## Objective

Build `SourceKitDiagnosticsService`, a service that uses SourceKittenFramework to request real-time diagnostics for a Swift source string without invoking a full `swiftc` compilation. This powers the inline error squiggles in the editor as the user types.

## Acceptance Criteria

- [ ] `SourceKitDiagnosticsService.diagnostics(for source: String) async -> [SwiftDiagnostic]` exists
- [ ] Returns `[SwiftDiagnostic]` (same model as in `SwiftCompilerService`) with line, column, severity, message
- [ ] Errors and warnings are both returned; notes may be omitted if SourceKit doesn't surface them cleanly
- [ ] Returns an empty array on any internal SourceKit failure (never throws to the caller)
- [ ] A basic test verifies that a source string with an obvious type error returns at least one diagnostic

## Notes

SourceKittenFramework communicates with `sourcekitd` via XPC. Use `SourceKittenFramework.Request.diagnostics(...)` or the equivalent API — check the SourceKitten README and source for the correct request type.

The source string is passed as a virtual file — SourceKit does not need a file on disk to return diagnostics, though some versions work better with a temp file path hint. Use a stable virtual path like `/tmp/UserIcon.swift`.

`SwiftDiagnostic` is already defined in `SwiftCompilerService.swift` — import or share the model. If the two services are in different files, extract `SwiftDiagnostic` into its own file (`Models/SwiftDiagnostic.swift`) to avoid duplication.

This service intentionally does not compile to a dylib — it is only for editor feedback. Response time should be under ~500ms for a typical icon source file.
