import Foundation
import Testing
@testable import QuickIcons

struct SourceKitDiagnosticsServiceTests {

    /// Verifies that an obviously broken Swift source (type mismatch) returns at least one diagnostic.
    @Test func typeErrorYieldsDiagnostic() async throws {
        let source = "let x: Int = \"hello\""
        let service = SourceKitDiagnosticsService()
        let result = await service.diagnostics(for: source)
        let diagnostics = try result.get()
        #expect(diagnostics.count >= 1)
        let hasError = diagnostics.contains { $0.severity == .error }
        #expect(hasError)
    }

    /// Verifies that valid Swift source returns zero diagnostics.
    @Test func validSourceYieldsNoDiagnostics() async throws {
        let service = SourceKitDiagnosticsService()
        let result = await service.diagnostics(for: "let x: Int = 42")
        let diagnostics = try result.get()
        #expect(diagnostics.isEmpty)
    }

    /// Empty source is a success with no diagnostics — not a failure — so the
    /// UI doesn't flag an empty buffer as "toolchain unavailable".
    @Test func emptySourceReturnsEmptySuccess() async throws {
        let service = SourceKitDiagnosticsService()
        let result = await service.diagnostics(for: "")
        let diagnostics = try result.get()
        #expect(diagnostics.isEmpty)
    }

    /// A runner that throws simulates a sourcekitd failure — the service must
    /// propagate that as `.failure` so the UI can surface "diagnostics
    /// unavailable" instead of pretending the code is clean.
    @Test func runnerFailurePropagatesAsFailure() async {
        struct BoomRunner: DiagnosticsRequestRunning {
            struct Boom: Error {}
            func run(yaml: String) async throws -> [String: Any] {
                throw Boom()
            }
        }
        let service = SourceKitDiagnosticsService(runner: BoomRunner())
        let result = await service.diagnostics(for: "let x = 1")
        switch result {
        case .success:
            Issue.record("expected .failure when runner throws, got .success")
        case .failure:
            break
        }
    }

    /// A runner that returns a response without `key.diagnostics` is a valid
    /// "clean" response — the service maps that to `.success([])`.
    @Test func runnerWithEmptyResponseYieldsEmptySuccess() async throws {
        struct EmptyRunner: DiagnosticsRequestRunning {
            func run(yaml: String) async throws -> [String: Any] {
                [:]
            }
        }
        let service = SourceKitDiagnosticsService(runner: EmptyRunner())
        let result = await service.diagnostics(for: "let x = 1")
        let diagnostics = try result.get()
        #expect(diagnostics.isEmpty)
    }

    /// A runner that returns canned diagnostic dictionaries exercises the
    /// parsing path without spawning sourcekitd — a real error shape is
    /// converted to `SwiftDiagnostic.error`.
    @Test func runnerWithCannedDiagnosticsParsesSeverity() async throws {
        struct CannedRunner: DiagnosticsRequestRunning {
            func run(yaml: String) async throws -> [String: Any] {
                [
                    "key.diagnostics": [
                        [
                            "key.description": "cannot convert value of type 'String' to expected type 'Int'",
                            "key.line": Int64(1),
                            "key.column": Int64(14),
                            "key.severity": "source.diagnostic.severity.error"
                        ]
                    ]
                ]
            }
        }
        let service = SourceKitDiagnosticsService(runner: CannedRunner())
        let result = await service.diagnostics(for: "let x: Int = \"hello\"")
        let diagnostics = try result.get()
        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.line == 1)
    }
}
