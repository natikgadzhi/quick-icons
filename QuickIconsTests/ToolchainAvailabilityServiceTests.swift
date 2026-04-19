//
//  ToolchainAvailabilityServiceTests.swift
//  QuickIconsTests
//

import Foundation
import Testing
@testable import QuickIcons

// MARK: - Fake runner helpers

/// Creates a `ProcessRunner` that returns a fixed result for every call.
private func fakeRunner(exitCode: Int32, stdout: String, stderr: String = "") -> ProcessRunner {
    return { _ in
        ProcessResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
    }
}

/// Creates a `ProcessRunner` that returns different results for successive calls.
/// The `responses` array is consumed in order; the last response is repeated if exhausted.
private func sequentialRunner(_ responses: [ProcessResult]) -> ProcessRunner {
    let storage = LockIsolated(responses)
    return { _ in
        storage.withLock { list -> ProcessResult in
            if list.count > 1 {
                return list.removeFirst()
            }
            return list[0]
        }
    }
}

/// Simple lock-based wrapper so we can mutate state from a Sendable closure.
private final class LockIsolated<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) { self.value = value }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

// MARK: - probeToolchain tests

struct ToolchainProbeTests {

    // MARK: xcrun path resolution fails → unavailable

    @Test func xcrunFailsReturnsUnavailable() async {
        let runner = fakeRunner(exitCode: 1, stdout: "", stderr: "xcrun: error: unable to find utility")
        let (available, reason) = await probeToolchain(runner: runner)
        #expect(!available)
        #expect(reason != nil)
        #expect(reason!.contains("xcrun failed"))
    }

    @Test func xcrunSucceedsButEmptyPathReturnsUnavailable() async {
        // xcrun exits 0 but returns empty stdout — shouldn't happen in practice but guard for it.
        let runner = fakeRunner(exitCode: 0, stdout: "   \n", stderr: "")
        let (available, reason) = await probeToolchain(runner: runner)
        #expect(!available)
        #expect(reason != nil)
        #expect(reason!.contains("empty path"))
    }

    // MARK: --version exits nonzero → unavailable

    @Test func swiftcVersionExitsNonzeroReturnsUnavailable() async {
        let xcrunSuccess = ProcessResult(exitCode: 0, stdout: "/usr/bin/swiftc\n", stderr: "")
        let versionFailure = ProcessResult(exitCode: 1, stdout: "", stderr: "internal error")
        let runner = sequentialRunner([xcrunSuccess, versionFailure])

        let (available, reason) = await probeToolchain(runner: runner)
        #expect(!available)
        #expect(reason != nil)
        #expect(reason!.contains("exited with code 1"))
    }

    // MARK: empty stdout from --version → unavailable

    @Test func swiftcVersionEmptyStdoutReturnsUnavailable() async {
        let xcrunSuccess = ProcessResult(exitCode: 0, stdout: "/usr/bin/swiftc\n", stderr: "")
        let versionEmpty = ProcessResult(exitCode: 0, stdout: "", stderr: "")
        let runner = sequentialRunner([xcrunSuccess, versionEmpty])

        let (available, reason) = await probeToolchain(runner: runner)
        #expect(!available)
        #expect(reason != nil)
        #expect(reason!.contains("unexpected output"))
    }

    // MARK: stdout from --version lacks "Swift" → unavailable

    @Test func swiftcVersionMissingSwiftKeywordReturnsUnavailable() async {
        let xcrunSuccess = ProcessResult(exitCode: 0, stdout: "/usr/bin/swiftc\n", stderr: "")
        let versionWeird = ProcessResult(exitCode: 0, stdout: "clang version 14.0.0", stderr: "")
        let runner = sequentialRunner([xcrunSuccess, versionWeird])

        let (available, reason) = await probeToolchain(runner: runner)
        #expect(!available)
        #expect(reason != nil)
        #expect(reason!.contains("unexpected output"))
    }

    // MARK: happy path → available

    @Test func happyPathReturnsAvailable() async {
        let xcrunSuccess = ProcessResult(exitCode: 0, stdout: "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc\n", stderr: "")
        let versionSuccess = ProcessResult(exitCode: 0, stdout: "swift-driver version: 1.90.11 Apple Swift version 5.10 (swiftlang-5.10.0.13 clang-1500.3.9.4)\nTarget: arm64-apple-macosx14.0\n", stderr: "")
        let runner = sequentialRunner([xcrunSuccess, versionSuccess])

        let (available, reason) = await probeToolchain(runner: runner)
        #expect(available)
        #expect(reason == nil)
    }
}
