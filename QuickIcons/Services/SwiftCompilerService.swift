//
//  SwiftCompilerService.swift
//  QuickIcons
//

import Foundation

// MARK: - Diagnostic model

/// A single compiler diagnostic (error, warning, or note) from swiftc.
struct SwiftDiagnostic: Sendable, Equatable {
    enum Severity: String, Sendable, Equatable {
        case error
        case warning
        case note
    }

    let line: Int
    let column: Int
    let severity: Severity
    let message: String
}

// MARK: - Compilation result

/// The result of a compile(source:) call.
enum CompilationResult: Sendable {
    /// The source compiled successfully; dylibURL points to the output dynamic library.
    case success(dylibURL: URL)
    /// The source failed to compile; diagnostics contains all parsed errors/warnings/notes.
    case failure(diagnostics: [SwiftDiagnostic])
}

// MARK: - SwiftCompilerService

/// Compiles user-supplied Swift source to a dynamic library via `swiftc`.
///
/// The service appends a bridge function that exposes `_quickIconsMakeView` as a
/// C symbol so the dylib can be loaded via `dlsym` by `IconPreviewService`.
@MainActor
final class SwiftCompilerService {

    // Stable dylib path — reused across compiles so we never accumulate files.
    private let dylibURL: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("quickicons-usericon.dylib")

    // Resolved lazily on first compile (off the main thread via async context)
    // to avoid blocking MainActor during init with synchronous xcrun calls.
    private var sdkPath: String?
    private var swiftcPath: String?

    init() {}

    // MARK: - Public API

    /// Compiles `source` to a dylib, instantiating `viewName` in the bridge.
    /// Returns `.success(dylibURL)` on success or `.failure(diagnostics)` when
    /// swiftc reports errors. Callers are responsible for resolving `viewName`
    /// (and rejecting non-icon source) via ``IconSourceAnalysis``.
    func compile(source: String, viewName: String) async -> CompilationResult {
        if sdkPath == nil {
            sdkPath = await Task.detached { Self.resolveSDKPath() }.value
        }
        if swiftcPath == nil {
            swiftcPath = await Task.detached { Self.resolveSwiftcPath() }.value
        }

        let fm = FileManager.default
        let sourceURL = fm.temporaryDirectory
            .appendingPathComponent("quickicons-usericon-\(UUID().uuidString).swift")

        let augmented = source + "\n" + bridgeSource(viewName: viewName)
        do {
            try augmented.write(to: sourceURL, atomically: true, encoding: .utf8)
        } catch {
            return .failure(diagnostics: [
                SwiftDiagnostic(line: 0, column: 0, severity: .error,
                                message: "Failed to write temp source file: \(error.localizedDescription)")
            ])
        }
        defer { try? fm.removeItem(at: sourceURL) }

        if fm.fileExists(atPath: dylibURL.path) {
            try? fm.removeItem(at: dylibURL)
        }

        let args: [String] = [
            swiftcPath ?? "/usr/bin/swiftc",
            "-emit-library",
            "-o", dylibURL.path,
            "-module-name", "UserIcon",
            sourceURL.path,
            "-sdk", sdkPath ?? "",
            "-target", BuildEnvironment.targetTriple,
        ]

        let (exitCode, stderr) = await runProcess(args)

        if exitCode == 0 {
            return .success(dylibURL: dylibURL)
        } else {
            return .failure(diagnostics: parseStderr(stderr))
        }
    }

    // MARK: - Bridge injection

    // NOTE: @_cdecl requires a C-compatible return type. AnyView cannot be used directly,
    // so the bridge returns an opaque pointer to a heap-retained AnyObject wrapping AnyView.
    // IconPreviewService (task 09) will retrieve this via dlsym and cast back using Unmanaged.
    private func bridgeSource(viewName: String) -> String {
        """
        import SwiftUI
        @_cdecl("_quickIconsMakeView")
        public func _quickIconsMakeView(_ size: Double) -> UnsafeMutableRawPointer {
            let view = AnyView(\(viewName)(size: CGFloat(size)))
            return Unmanaged.passRetained(view as AnyObject).toOpaque()
        }
        """
    }

    // MARK: - stderr parsing

    /// Parses swiftc stderr, extracting structured diagnostics.
    /// Expected format: `<file>:<line>:<column>: <severity>: <message>`
    func parseStderr(_ stderr: String) -> [SwiftDiagnostic] {
        // Match on any path prefix so tests can pass arbitrary stderr strings.
        let pattern = #"^.*:(\d+):(\d+): (error|warning|note): (.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        var diagnostics: [SwiftDiagnostic] = []
        let lines = stderr.components(separatedBy: "\n")
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: range) else { continue }

            func capture(_ i: Int) -> String? {
                guard let r = Range(match.range(at: i), in: line) else { return nil }
                return String(line[r])
            }

            guard
                let lineStr = capture(1), let lineNum = Int(lineStr),
                let colStr = capture(2), let colNum = Int(colStr),
                let severityStr = capture(3),
                let severity = SwiftDiagnostic.Severity(rawValue: severityStr),
                let message = capture(4)
            else { continue }

            diagnostics.append(SwiftDiagnostic(line: lineNum, column: colNum, severity: severity, message: message))
        }
        return diagnostics
    }

    // MARK: - Process helpers

    private func runProcess(_ args: [String]) async -> (exitCode: Int32, stderr: String) {
        await withCheckedContinuation { continuation in
            // Run Process setup + waitUntilExit() off the main thread so the
            // @MainActor caller does not block the UI during compilation.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: args[0])
                process.arguments = Array(args.dropFirst())

                let stderrPipe = Pipe()
                process.standardOutput = Pipe() // discard stdout
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, "Failed to launch swiftc: \(error.localizedDescription)"))
                    return
                }

                process.waitUntilExit()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stderr))
            }
        }
    }

    // MARK: - Toolchain resolution

    nonisolated private static func resolveSDKPath() -> String {
        let result = runSyncProcess("/usr/bin/xcrun", args: ["--sdk", "macosx", "--show-sdk-path"])
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func resolveSwiftcPath() -> String {
        let result = runSyncProcess("/usr/bin/xcrun", args: ["-f", "swiftc"])
        let path = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "/usr/bin/swiftc" : path
    }

    /// Runs a process synchronously and returns its stdout as a string.
    nonisolated private static func runSyncProcess(_ executable: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // discard
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
