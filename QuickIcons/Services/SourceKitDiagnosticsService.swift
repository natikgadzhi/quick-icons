import Foundation
import SourceKittenFramework

/// Result of a diagnostics request.
///
/// We distinguish a genuine "no diagnostics" outcome (clean code) from an
/// unavailable toolchain / sourcekitd failure so the UI can surface a
/// "diagnostics unavailable" affordance instead of silently implying the code
/// is clean.
typealias DiagnosticsResult = Result<[SwiftDiagnostic], any Error>

/// Errors originating from `SourceKitDiagnosticsService` itself (as opposed to
/// errors bubbled up from sourcekitd via SourceKittenFramework).
enum SourceKitDiagnosticsError: Error {
    /// The service could not write the source to a temporary file — sourcekitd
    /// requires the input to exist on disk.
    case tempFileWriteFailed
}

/// Abstraction over the raw sourcekitd YAML round-trip. Injected so tests can
/// supply canned responses or simulated failures without spawning sourcekitd.
///
/// The response is projected into `[String: Any]` (rather than
/// `[String: SourceKitRepresentable]`) so the test target does not need to
/// link SourceKittenFramework to implement the protocol.
protocol DiagnosticsRequestRunning: Sendable {
    func run(yaml: String) async throws -> [String: Any]
}

/// Default runner — forwards to SourceKittenFramework's `Request.yamlRequest`.
struct SourceKittenDiagnosticsRunner: DiagnosticsRequestRunning {
    func run(yaml: String) async throws -> [String: Any] {
        let raw = try await Request.yamlRequest(yaml: yaml).asyncSend()
        return raw.mapValues { $0 as Any }
    }
}

/// `SourceKitDiagnosticsService` requests real-time diagnostics for a Swift source string
/// via SourceKittenFramework / sourcekitd, without invoking a full `swiftc` compilation.
///
/// Uses `source.request.diagnostics` — the SourceKit request dedicated to returning
/// type-checking diagnostics synchronously for a file on disk.
///
/// Returns a `Result` so the UI can distinguish a clean parse (empty success)
/// from a sourcekitd failure (unavailable toolchain, crash, malformed response).
nonisolated struct SourceKitDiagnosticsService: Sendable {

    private let runner: any DiagnosticsRequestRunning

    init(runner: any DiagnosticsRequestRunning = SourceKittenDiagnosticsRunner()) {
        self.runner = runner
    }

    /// Returns diagnostics for `source`. Writes `source` to a temporary file and queries
    /// SourceKit's dedicated diagnostics request with the system Swift SDK.
    ///
    /// Returns `.success([])` for empty input or when sourcekitd returns no diagnostics.
    /// Returns `.failure(...)` when the temp file cannot be written or sourcekitd
    /// itself fails (crash, timeout, malformed response).
    func diagnostics(for source: String) async -> DiagnosticsResult {
        guard !source.isEmpty else { return .success([]) }

        guard let tmpURL = writeTempFile(source) else {
            return .failure(SourceKitDiagnosticsError.tempFileWriteFailed)
        }
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Resolve the SDK path lazily on the first invocation via the shared
        // actor-backed cache — the first `xcrun` spawn runs off-thread so it
        // doesn't block MainActor on the first keystroke.
        let sdkPath = await SDKPathCache.shared.path()

        let path = tmpURL.path
        let compilerArgs = buildCompilerArgs(path: path, sdkPath: sdkPath)
        let yaml = buildDiagnosticsYAMLRequest(path: path, compilerArgs: compilerArgs)

        do {
            let response = try await runner.run(yaml: yaml)
            return .success(parseDiagnostics(from: response))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private helpers

    /// `source.request.diagnostics` requires the file to exist on disk and returns
    /// type-checking diagnostics synchronously.
    private func buildDiagnosticsYAMLRequest(
        path: String,
        compilerArgs: [String]
    ) -> String {
        func yamlString(_ s: String) -> String {
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return "\"\(escaped)\""
        }

        let argsYAML = compilerArgs.map { yamlString($0) }.joined(separator: ", ")

        return """
        {
          key.request: source.request.diagnostics,
          key.sourcefile: \(yamlString(path)),
          key.compilerargs: [\(argsYAML)]
        }
        """
    }

    private func writeTempFile(_ source: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SourceKitDiag-\(UUID().uuidString).swift")
        do {
            try source.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func buildCompilerArgs(path: String, sdkPath: String?) -> [String] {
        var args: [String] = [path]
        if let sdkPath {
            args += ["-sdk", sdkPath]
        }
        args += ["-target", BuildEnvironment.targetTriple]
        args += ["-module-name", "UserIcon"]
        return args
    }

    private func parseDiagnostics(
        from response: [String: Any]
    ) -> [SwiftDiagnostic] {
        // sourcekitd may return either `[[String: SourceKitRepresentable]]`
        // (real runs) or `[[String: Any]]` (tests) — accept either shape.
        if let nested = response["key.diagnostics"] as? [[String: Any]] {
            return nested.compactMap { parseDiagnostic(from: $0) }
        }
        if let nested = response["key.diagnostics"] as? [[String: SourceKitRepresentable]] {
            return nested.compactMap { parseDiagnostic(from: $0.mapValues { $0 as Any }) }
        }
        return []
    }

    private func parseDiagnostic(from dict: [String: Any]) -> SwiftDiagnostic? {
        guard
            let message = dict["key.description"] as? String,
            let line = dict["key.line"] as? Int64,
            let column = dict["key.column"] as? Int64,
            let severityUID = dict["key.severity"] as? String
        else {
            return nil
        }

        return SwiftDiagnostic(
            line: Int(line),
            column: Int(column),
            severity: parseSeverity(severityUID),
            message: message
        )
    }

    private func parseSeverity(_ uid: String) -> SwiftDiagnostic.Severity {
        if uid.hasSuffix(".error") { return .error }
        if uid.hasSuffix(".warning") { return .warning }
        return .note
    }
}
