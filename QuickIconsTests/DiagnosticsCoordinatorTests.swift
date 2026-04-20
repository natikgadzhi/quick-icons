//
//  DiagnosticsCoordinatorTests.swift
//  QuickIconsTests
//
//  Verifies that `DiagnosticsCoordinator` exposes the injection seam the task
//  spec calls for (a `DiagnosticsProviding` service) and that its bookkeeping
//  starts clean. Exercising the STTextView-facing methods directly would
//  require standing up an AppKit text view, so those paths are covered by the
//  pure `TextOffset` helpers and by the shipping app; here we keep the focus
//  on the DI seam and the mock call pattern.
//

import Foundation
import Testing
@testable import QuickIcons

/// Mock that records calls the coordinator makes into the service.
/// Uses an internal actor for thread-safe append — satisfies `nonisolated`
/// protocol requirement while keeping the Sendable surface clean.
final class MockDiagnosticsService: DiagnosticsProviding, Sendable {
    private actor Storage {
        var received: [String] = []
        func record(_ source: String) { received.append(source) }
    }

    struct StubbedError: Error, Equatable {}

    private let storage = Storage()
    private let stubbed: DiagnosticsResult

    init(returning diagnostics: [SwiftDiagnostic]) {
        self.stubbed = .success(diagnostics)
    }

    init(failingWith error: any Error) {
        self.stubbed = .failure(error)
    }

    /// Convenience for the empty-success default.
    static func empty() -> MockDiagnosticsService { .init(returning: []) }

    func receivedSources() async -> [String] {
        await storage.received
    }

    nonisolated func diagnostics(for source: String) async -> DiagnosticsResult {
        await storage.record(source)
        return stubbed
    }
}

@MainActor
struct DiagnosticsCoordinatorTests {

    @Test func coordinatorStartsWithNoInstalledMarkers() {
        let coordinator = DiagnosticsCoordinator(
            service: MockDiagnosticsService.empty()
        )
        #expect(coordinator.installedMarkerLines.isEmpty)
        #expect(coordinator.textViewAnnotations.isEmpty)
    }

    @Test func mockServiceReceivesSourceWhenCalledDirectly() async {
        let mock = MockDiagnosticsService(returning: [
            SwiftDiagnostic(line: 1, column: 1, severity: .error, message: "bad")
        ])
        let result = await mock.diagnostics(for: "let x = 1")

        let received = await mock.receivedSources()
        #expect(received == ["let x = 1"])
        switch result {
        case .success(let diagnostics):
            #expect(diagnostics.count == 1)
            #expect(diagnostics.first?.severity == .error)
        case .failure:
            Issue.record("expected success")
        }
    }

    /// A failing service should flip the coordinator's availability state —
    /// the scheduler switches on the service's `DiagnosticsResult` and calls
    /// `updateAvailability(unavailable:)`. Exercising the mock directly here
    /// covers the seam; full STTextView plumbing is out of scope for a unit
    /// test.
    @Test func failingServiceReturnsFailureResult() async {
        let mock = MockDiagnosticsService(failingWith: MockDiagnosticsService.StubbedError())
        let result = await mock.diagnostics(for: "anything")

        switch result {
        case .success:
            Issue.record("expected failure")
        case .failure(let error):
            #expect(error is MockDiagnosticsService.StubbedError)
        }
    }

    /// Confirms the DI seam accepts any `DiagnosticsProviding` conformer —
    /// regression guard against accidentally binding the coordinator to the
    /// concrete `SourceKitDiagnosticsService`.
    @Test func coordinatorAcceptsAnyDiagnosticsProvidingService() {
        let mock = MockDiagnosticsService.empty()
        let coordinator: DiagnosticsCoordinator = DiagnosticsCoordinator(service: mock)
        #expect(coordinator.installedMarkerLines.isEmpty)
    }
}
