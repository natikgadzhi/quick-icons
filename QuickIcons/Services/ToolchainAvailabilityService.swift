//
//  ToolchainAvailabilityService.swift
//  QuickIcons
//

import Foundation

// MARK: - Probe abstraction

/// The result of running a single command via Process.
struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

/// A closure type that runs a command and returns its output.
/// Abstracted so tests can inject fake implementations.
typealias ProcessRunner = @Sendable ([String]) async -> ProcessResult

// MARK: - Default process runner

/// Runs a command with the given arguments and returns the result.
func defaultProcessRunner(_ args: [String]) async -> ProcessResult {
    await withCheckedContinuation { continuation in
        // Run Process setup + waitUntilExit() off the main thread so callers
        // on @MainActor do not block the UI while the probe runs.
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(filePath: args[0])
            process.arguments = Array(args.dropFirst())

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(returning: ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                return
            }

            process.waitUntilExit()
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            continuation.resume(returning: ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr))
        }
    }
}

// MARK: - Toolchain probe

/// Checks whether a real Swift toolchain is available.
///
/// Steps:
/// 1. Run `xcrun -f swiftc` to resolve the real swiftc path (avoids the macOS stub shim).
/// 2. Invoke `<resolved-path> --version` and require exit code 0 and stdout containing "Swift".
///
/// - Parameter runner: Process runner to use. Defaults to `defaultProcessRunner`.
/// - Returns: `(available: Bool, reason: String?)` — reason is non-nil on failure.
func probeToolchain(runner: ProcessRunner = defaultProcessRunner) async -> (available: Bool, reason: String?) {
    // Step 1: resolve the real swiftc path via xcrun.
    let xcrunResult = await runner(["/usr/bin/xcrun", "-f", "swiftc"])
    guard xcrunResult.exitCode == 0 else {
        return (false, "xcrun failed to locate swiftc (exit \(xcrunResult.exitCode)). Install Xcode or Xcode Command Line Tools.")
    }

    let swiftcPath = xcrunResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !swiftcPath.isEmpty else {
        return (false, "xcrun returned an empty path for swiftc. Install Xcode or Xcode Command Line Tools.")
    }

    // Step 2: verify the resolved swiftc responds properly.
    let versionResult = await runner([swiftcPath, "--version"])
    guard versionResult.exitCode == 0 else {
        return (false, "swiftc at '\(swiftcPath)' exited with code \(versionResult.exitCode). The toolchain may be damaged.")
    }

    let versionOutput = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !versionOutput.isEmpty, versionOutput.contains("Swift") else {
        return (false, "swiftc --version produced unexpected output. The toolchain may be incomplete.")
    }

    return (true, nil)
}
