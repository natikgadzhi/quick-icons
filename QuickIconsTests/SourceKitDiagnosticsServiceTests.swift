import Foundation
import Testing
@testable import QuickIcons

struct SourceKitDiagnosticsServiceTests {

    /// Verifies that an obviously broken Swift source (type mismatch) returns at least one diagnostic.
    @Test func typeErrorYieldsDiagnostic() async {
        let source = "let x: Int = \"hello\""
        let service = SourceKitDiagnosticsService()
        let diagnostics = await service.diagnostics(for: source)
        #expect(diagnostics.count >= 1)
        let hasError = diagnostics.contains { $0.severity == .error }
        #expect(hasError)
    }

    /// Verifies that valid Swift source returns zero diagnostics.
    @Test func validSourceYieldsNoDiagnostics() async {
        let service = SourceKitDiagnosticsService()
        let diagnostics = await service.diagnostics(for: "let x: Int = 42")
        #expect(diagnostics.isEmpty)
    }

    /// Verifies the service never throws — an empty string is safe to pass.
    @Test func emptySourceReturnsEmpty() async {
        let service = SourceKitDiagnosticsService()
        let diagnostics = await service.diagnostics(for: "")
        #expect(diagnostics.isEmpty)
    }
}
