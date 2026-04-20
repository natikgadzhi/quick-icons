import Foundation
import SourceKittenFramework

/// `SourceKitDiagnosticsService` requests real-time diagnostics for a Swift source string
/// via SourceKittenFramework / sourcekitd, without invoking a full `swiftc` compilation.
///
/// Uses `source.request.diagnostics` — the SourceKit request dedicated to returning
/// type-checking diagnostics synchronously for a file on disk.
///
/// The service never throws to the caller — any internal SourceKit failure returns an empty array.
nonisolated struct SourceKitDiagnosticsService: Sendable {

    init() {}

    /// Returns diagnostics for `source`. Writes `source` to a temporary file and queries
    /// SourceKit's dedicated diagnostics request with the system Swift SDK.
    /// Returns an empty array on any SourceKit failure.
    func diagnostics(for source: String) async -> [SwiftDiagnostic] {
        guard !source.isEmpty else { return [] }

        guard let tmpURL = writeTempFile(source) else { return [] }
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Resolve the SDK path lazily on the first invocation via the shared
        // actor-backed cache — the first `xcrun` spawn runs off-thread so it
        // doesn't block MainActor on the first keystroke.
        let sdkPath = await SDKPathCache.shared.path()

        let path = tmpURL.path
        let compilerArgs = buildCompilerArgs(path: path, sdkPath: sdkPath)
        let yaml = buildDiagnosticsYAMLRequest(path: path, compilerArgs: compilerArgs)

        do {
            let response = try await Request.yamlRequest(yaml: yaml).asyncSend()
            return parseDiagnostics(from: response)
        } catch {
            return []
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
        from response: [String: SourceKitRepresentable]
    ) -> [SwiftDiagnostic] {
        guard let rawDiagnostics = response["key.diagnostics"] as? [[String: SourceKitRepresentable]] else {
            return []
        }
        return rawDiagnostics.compactMap { parseDiagnostic(from: $0) }
    }

    private func parseDiagnostic(from dict: [String: SourceKitRepresentable]) -> SwiftDiagnostic? {
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
