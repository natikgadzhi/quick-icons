//
//  SwiftCompilerServiceTests.swift
//  QuickIconsTests
//

import Foundation
import Testing
@testable import QuickIcons

// MARK: - SwiftDiagnostic model tests

struct SwiftDiagnosticTests {
    @Test func severityRawValues() {
        #expect(SwiftDiagnostic.Severity(rawValue: "error") == .error)
        #expect(SwiftDiagnostic.Severity(rawValue: "warning") == .warning)
        #expect(SwiftDiagnostic.Severity(rawValue: "note") == .note)
        #expect(SwiftDiagnostic.Severity(rawValue: "unknown") == nil)
    }

    @Test func diagnosticEquality() {
        let a = SwiftDiagnostic(line: 1, column: 5, severity: .error, message: "boom")
        let b = SwiftDiagnostic(line: 1, column: 5, severity: .error, message: "boom")
        #expect(a.line == b.line)
        #expect(a.column == b.column)
        #expect(a.severity == b.severity)
        #expect(a.message == b.message)
    }
}

// MARK: - stderr parsing tests

@MainActor
struct SwiftCompilerServiceParserTests {
    let service = SwiftCompilerService()

    @Test func parseSingleErrorLine() {
        let stderr = "/tmp/foo.swift:3:10: error: use of unresolved identifier 'Foo'"
        let diags = service.parseStderr(stderr)
        #expect(diags.count == 1)
        #expect(diags[0].line == 3)
        #expect(diags[0].column == 10)
        #expect(diags[0].severity == .error)
        #expect(diags[0].message == "use of unresolved identifier 'Foo'")
    }

    @Test func parseWarningLine() {
        let stderr = "/tmp/bar.swift:7:1: warning: result of call is unused"
        let diags = service.parseStderr(stderr)
        #expect(diags.count == 1)
        #expect(diags[0].severity == .warning)
        #expect(diags[0].line == 7)
        #expect(diags[0].column == 1)
    }

    @Test func parseNoteLine() {
        let stderr = "/tmp/baz.swift:2:3: note: did you mean 'bar'?"
        let diags = service.parseStderr(stderr)
        #expect(diags.count == 1)
        #expect(diags[0].severity == .note)
    }

    @Test func parseMultipleDiagnostics() {
        let stderr = """
        /tmp/foo.swift:1:1: error: expected '{' in class
        /tmp/foo.swift:2:5: warning: unused variable 'x'
        /tmp/foo.swift:3:9: note: declared here
        """
        let diags = service.parseStderr(stderr)
        #expect(diags.count == 3)
        #expect(diags[0].severity == .error)
        #expect(diags[1].severity == .warning)
        #expect(diags[2].severity == .note)
    }

    @Test func parseIgnoresNonDiagnosticLines() {
        let stderr = """
        <unknown>:0: note: just info
        some random output
        /tmp/foo.swift:5:2: error: boom
        another random line without colons
        """
        let diags = service.parseStderr(stderr)
        // Only the line with proper format should match
        let errors = diags.filter { $0.severity == .error }
        #expect(errors.count == 1)
        #expect(errors[0].line == 5)
    }

    @Test func parseEmptyStderr() {
        let diags = service.parseStderr("")
        #expect(diags.isEmpty)
    }

    @Test func parsePathWithSpaces() {
        let stderr = "/Users/natik/My Project/foo.swift:10:20: error: type mismatch"
        let diags = service.parseStderr(stderr)
        #expect(diags.count == 1)
        #expect(diags[0].line == 10)
        #expect(diags[0].column == 20)
        #expect(diags[0].message == "type mismatch")
    }
}

// MARK: - Integration tests (actual swiftc invocation)

@MainActor
struct SwiftCompilerServiceIntegrationTests {
    let service = SwiftCompilerService()

    /// A minimal SwiftUI view that satisfies the bridge's expectations.
    /// The service appends the bridge function automatically; we only provide the view definition.
    private let trivialSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            Circle()
                .fill(Color.blue)
                .frame(width: size, height: size)
        }
    }
    """

    /// Source that has a deliberate syntax error.
    private let brokenSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            this is not valid Swift }{
        }
    }
    """

    @Test func successfulCompileReturnsDylibURL() async {
        let result = await service.compile(source: trivialSource)
        switch result {
        case .success(let url):
            #expect(FileManager.default.fileExists(atPath: url.path), "dylib should exist on disk")
            #expect(url.lastPathComponent == "quickicons-usericon.dylib")
        case .failure(let diagnostics):
            // Print diagnostics for easier debugging on failure
            let messages = diagnostics.map { "\($0.severity.rawValue) \($0.line):\($0.column) \($0.message)" }
            #expect(Bool(false), "Expected success but got failure: \(messages.joined(separator: "; "))")
        }
    }

    @Test func failedCompileReturnsDiagnosticsNotThrownError() async {
        let result = await service.compile(source: brokenSource)
        switch result {
        case .success:
            #expect(Bool(false), "Expected failure but got success")
        case .failure(let diagnostics):
            #expect(!diagnostics.isEmpty, "Should have at least one diagnostic for broken source")
            let errors = diagnostics.filter { $0.severity == .error }
            #expect(!errors.isEmpty, "Should have at least one error diagnostic")
        }
    }

    @Test func repeatedCompileOverwritesDylib() async {
        // First compile
        _ = await service.compile(source: trivialSource)
        // Second compile — should succeed without accumulating files
        let result = await service.compile(source: trivialSource)
        switch result {
        case .success(let url):
            #expect(FileManager.default.fileExists(atPath: url.path))
        case .failure(let diags):
            let msgs = diags.map(\.message)
            #expect(Bool(false), "Second compile failed: \(msgs)")
        }
    }
}
