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

    public nonisolated init() {}

    /// Returns diagnostics for `source`. Writes `source` to a temporary file and queries
    /// SourceKit's dedicated diagnostics request with the system Swift SDK.
    /// Returns an empty array on any SourceKit failure.
    nonisolated func diagnostics(for source: String) async -> [SwiftDiagnostic] {
        guard !source.isEmpty else { return [] }

        guard let tmpURL = writeTempFile(source) else { return [] }
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let path = tmpURL.path
        let sdkPath = getSDKPath()
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

    /// Builds a `source.request.diagnostics` YAML request for the given file path.
    ///
    /// `source.request.diagnostics` is the SourceKit request dedicated to returning
    /// type-checking diagnostics synchronously. It requires the file to exist on disk.
    private nonisolated func buildDiagnosticsYAMLRequest(
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

    private nonisolated func writeTempFile(_ source: String) -> URL? {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("SourceKitDiag-\(UUID().uuidString).swift")
        do {
            try source.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private nonisolated func getSDKPath() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["--show-sdk-path", "--sdk", "macosx"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private nonisolated func buildCompilerArgs(path: String, sdkPath: String?) -> [String] {
        var args: [String] = [path]
        if let sdk = sdkPath {
            args += ["-sdk", sdk]
        }
        args += ["-target", "arm64-apple-macos13.0"]
        args += ["-module-name", "UserIcon"]
        return args
    }

    private nonisolated func parseDiagnostics(
        from response: [String: SourceKitRepresentable]
    ) -> [SwiftDiagnostic] {
        guard let rawDiagnostics = response["key.diagnostics"] as? [[String: SourceKitRepresentable]] else {
            return []
        }
        return rawDiagnostics.compactMap { parseDiagnostic(from: $0) }
    }

    private nonisolated func parseDiagnostic(from dict: [String: SourceKitRepresentable]) -> SwiftDiagnostic? {
        guard
            let message = dict["key.description"] as? String,
            let line = dict["key.line"] as? Int64,
            let column = dict["key.column"] as? Int64,
            let severityUID = dict["key.severity"] as? String
        else {
            return nil
        }

        let severity = parseSeverity(severityUID)
        return SwiftDiagnostic(
            line: Int(line),
            column: Int(column),
            severity: severity,
            message: message
        )
    }

    private nonisolated func parseSeverity(_ uid: String) -> SwiftDiagnostic.Severity {
        if uid.hasSuffix(".error") { return .error }
        if uid.hasSuffix(".warning") { return .warning }
        return .note
    }
}
