/// SwiftDiagnostic represents a single compiler or editor diagnostic for a Swift source file.
///
/// This model is intentionally defined here for `SourceKitDiagnosticsService`.
/// Task 06 (SwiftCompilerService) defines the same model. Whichever PR merges second
/// should remove its duplicate and keep only one canonical definition — the lead agent
/// must resolve this conflict at merge time.
///
/// Shape must match exactly: line, column, severity (.error/.warning/.note), message.

// MARK: - Severity

/// Diagnostic severity level. `nonisolated` to prevent `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// from inferring actor isolation on this value type.
public nonisolated enum Severity: String, Sendable {
    case error
    case warning
    case note
}

// MARK: - SwiftDiagnostic

/// A single diagnostic from SourceKit or the Swift compiler.
/// Marked `nonisolated` to be safe to use from any concurrency context.
public nonisolated struct SwiftDiagnostic: Sendable {
    public nonisolated let line: Int
    public nonisolated let column: Int
    public nonisolated let severity: Severity
    public nonisolated let message: String

    public nonisolated init(line: Int, column: Int, severity: Severity, message: String) {
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
    }
}
