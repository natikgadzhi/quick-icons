import Foundation
import Testing
@testable import QuickIcons

// MARK: - Helpers

/// A canned-response runner used by the unit tests. The caller supplies either
/// a fixed result or a closure that runs when the service invokes `run(source:offset:)`.
/// Using a closure lets tests simulate cancellation mid-request and observe
/// the arguments the service passed in.
private struct StubRunner: CompletionRequestRunning {
    let body: @Sendable (String, Int) async throws -> [[String: Any]]

    func run(source: String, offset: Int) async throws -> [[String: Any]] {
        try await body(source, offset)
    }
}

private struct StubError: Error, Equatable {
    let tag: String
}

private func functionItem() -> [String: Any] {
    [
        "key.kind": "source.lang.swift.decl.function.free",
        "key.name": "print(_:separator:terminator:)",
        "key.description": "print(items: Any..., separator: String, terminator: String)",
        "key.sourcetext": "print(<#T##items: Any...##Any#>)",
        "key.typename": "Void"
    ]
}

private func keywordItem() -> [String: Any] {
    [
        "key.kind": "source.lang.swift.keyword",
        "key.name": "return",
        "key.description": "return",
        "key.sourcetext": "return"
        // deliberately no key.typename — keywords don't have one
    ]
}

// MARK: - Tests

struct SourceKitCompletionServiceTests {

    /// Maps a function completion with all fields populated.
    @Test func mapsFunctionCompletion() async throws {
        let runner = StubRunner { _, _ in [functionItem()] }
        let service = SourceKitCompletionService(runner: runner)

        let items = try await service.complete(source: "print", offset: 5)

        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.name == "print(_:separator:terminator:)")
        #expect(item.description == "print(items: Any..., separator: String, terminator: String)")
        #expect(item.sourcetext == "print(<#T##items: Any...##Any#>)")
        #expect(item.kind == .function)
        #expect(item.typeName == "Void")
    }

    /// Maps a keyword completion with no typeName.
    @Test func mapsKeywordCompletion() async throws {
        let runner = StubRunner { _, _ in [keywordItem()] }
        let service = SourceKitCompletionService(runner: runner)

        let items = try await service.complete(source: "func f() { r", offset: 12)

        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.name == "return")
        #expect(item.kind == .keyword)
        #expect(item.typeName == nil)
    }

    /// An empty `key.results` array projects to an empty item list.
    @Test func handlesEmptyResults() async throws {
        let runner = StubRunner { _, _ in [] }
        let service = SourceKitCompletionService(runner: runner)
        let items = try await service.complete(source: "let x = 1", offset: 9)
        #expect(items.isEmpty)
    }

    /// Empty source short-circuits before calling the runner.
    @Test func emptySourceReturnsEmptyWithoutCallingRunner() async throws {
        actor Counter { var value = 0; func bump() { value += 1 } }
        let counter = Counter()
        let runner = StubRunner { _, _ in
            await counter.bump()
            return []
        }
        let service = SourceKitCompletionService(runner: runner)
        let items = try await service.complete(source: "", offset: 0)
        #expect(items.isEmpty)
        let calls = await counter.value
        #expect(calls == 0)
    }

    /// Errors thrown by the runner propagate unchanged to the caller.
    @Test func propagatesErrorsFromRunner() async {
        let runner = StubRunner { _, _ in throw StubError(tag: "boom") }
        let service = SourceKitCompletionService(runner: runner)
        do {
            _ = try await service.complete(source: "let x = 1", offset: 9)
            Issue.record("expected runner error to propagate")
        } catch let error as StubError {
            #expect(error.tag == "boom")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    /// Cancelling the enclosing Task before the runner returns aborts the
    /// request with `CancellationError`.
    @Test func cancellationAbortsRequest() async {
        // Runner blocks until the task is cancelled, then honors cancellation
        // so the service's post-runner `checkCancellation` fires.
        let runner = StubRunner { _, _ in
            // Sleep long enough that we can cancel from outside; Task.sleep
            // throws CancellationError when the task is cancelled.
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return []
        }
        let service = SourceKitCompletionService(runner: runner)

        let task = Task {
            try await service.complete(source: "let x = 1", offset: 9)
        }
        // Give the child task a moment to enter the runner, then cancel.
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - Kind mapping

    @Test func kindMappingCoversCommonUIDs() {
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.function.free") == .function)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.function.method.instance") == .method)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.function.method.static") == .method)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.class") == .class)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.struct") == .struct)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.enum") == .enum)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.enumelement") == .enumCase)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.protocol") == .protocol)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.typealias") == .typealias)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.var.instance") == .property)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.var.local") == .localVar)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.var.global") == .globalVar)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.keyword") == .keyword)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.module") == .module)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.decl.mystery") == .other)
    }

    @Test func sfSymbolNameIsStableForAllKinds() {
        for kind in CompletionKind.allCases {
            #expect(!kind.sfSymbolName.isEmpty)
        }
    }
}
