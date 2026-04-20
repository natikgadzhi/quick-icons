import AppKit
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

    /// Every kind resolves to an SF Symbol that exists on the current system.
    /// If a mapping drifts to a symbol the OS doesn't ship, `NSImage(systemSymbolName:)`
    /// returns nil and the row view would render blank — this test pins that down.
    @Test func sfSymbolNamesResolveOnSystem() {
        for kind in CompletionKind.allCases {
            let image = NSImage(systemSymbolName: kind.sfSymbolName, accessibilityDescription: nil)
            #expect(image != nil, "missing SF Symbol for \(kind): \(kind.sfSymbolName)")
        }
    }

    /// Literal results (integer/string/boolean literals surfaced by SourceKit)
    /// bucket into `.literal` and pick the numeric SF Symbol.
    @Test func literalKindsMapToLiteral() {
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.literal.integer") == .literal)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.literal.string") == .literal)
        #expect(CompletionKind.from(sourceKitKind: "source.lang.swift.literal.boolean") == .literal)
        #expect(CompletionKind.literal.sfSymbolName == "number.square")
    }

    // MARK: - Placeholder parsing

    /// Simple `<#name#>` placeholders: the visible label is retained and the
    /// first placeholder's UTF-16 range points at it inside the stripped text.
    @Test func stripsSimplePlaceholders() {
        let item = SwiftCompletionItem(
            name: "foo",
            description: "foo(bar:)",
            sourcetext: "foo(<#bar#>)",
            kind: .function,
            typeName: nil
        )
        #expect(item.plainInsertText == "foo(bar)")
        #expect(item.firstPlaceholderUTF16Range == 4..<7)
    }

    /// Typed `<#T##label##Type#>` placeholders: only the middle `label`
    /// component is surfaced.
    @Test func stripsTypedPlaceholders() {
        let item = SwiftCompletionItem(
            name: "print(_:separator:terminator:)",
            description: "print(items: Any..., separator: String, terminator: String)",
            sourcetext: "print(<#T##items: Any...##Any#>)",
            kind: .function,
            typeName: "Void"
        )
        #expect(item.plainInsertText == "print(items: Any...)")
        // `items: Any...` is 13 UTF-16 units starting at offset 6 (after "print(").
        #expect(item.firstPlaceholderUTF16Range == 6..<19)
    }

    /// Plain sourcetext with no placeholders is returned verbatim and yields
    /// no placeholder range.
    @Test func plainSourceTextPassesThrough() {
        let item = SwiftCompletionItem(
            name: "return",
            description: "return",
            sourcetext: "return",
            kind: .keyword,
            typeName: nil
        )
        #expect(item.plainInsertText == "return")
        #expect(item.firstPlaceholderUTF16Range == nil)
    }

    /// Multiple placeholders: only the first placeholder's range is returned,
    /// but every placeholder is stripped to its visible label in the output.
    @Test func firstPlaceholderRangePointsAtFirstLabel() {
        let item = SwiftCompletionItem(
            name: "pair",
            description: "pair(a:b:)",
            sourcetext: "pair(<#T##a##Int#>, <#T##b##Int#>)",
            kind: .function,
            typeName: "Void"
        )
        #expect(item.plainInsertText == "pair(a, b)")
        #expect(item.firstPlaceholderUTF16Range == 5..<6)
    }

    // MARK: - Annotated description parser

    /// Plain strings (no XML-like tags) yield `nil` so the view layer falls
    /// back to its plain-text rendering path.
    @Test func parserRejectsUntaggedStrings() {
        #expect(AnnotatedDescriptionParser.parse("print(items: Any...)") == nil)
        #expect(AnnotatedDescriptionParser.parse("") == nil)
        #expect(AnnotatedDescriptionParser.parse("return") == nil)
    }

    /// A typical annotated-completion description: name + parenthesized
    /// argument label + type reference, each in its own run.
    @Test func parserSplitsCompletionDescription() throws {
        let xml = "<name>print</name>(<callarg.param>items</callarg.param>: <typeid.sys>Any</typeid.sys>)"
        let runs = try #require(AnnotatedDescriptionParser.parse(xml))

        // Expected run list: "print" | "(" | "items" | ": " | "Any" | ")"
        // Adjacent plain runs coalesce, so punctuation lands in two runs.
        #expect(runs.map(\.text) == ["print", "(", "items", ": ", "Any", ")"])
        #expect(runs.map(\.kind) == [.declName, .plain, .parameter, .plain, .typeRef, .plain])
    }

    /// Keyword completions surface the `keyword` tag.
    @Test func parserRecognizesKeywordTag() throws {
        let runs = try #require(AnnotatedDescriptionParser.parse("<keyword>return</keyword>"))
        #expect(runs.count == 1)
        #expect(runs[0].text == "return")
        #expect(runs[0].kind == .keyword)
    }

    /// The richer cursor-info vocabulary (`<Declaration><Type>…`) also parses.
    /// `Declaration` is a transparent container; inner `Type` spans become
    /// `.typeRef` runs.
    @Test func parserHandlesAnnotatedDecl() throws {
        let xml = "<Declaration>let x: <Type>Int</Type></Declaration>"
        let runs = try #require(AnnotatedDescriptionParser.parse(xml))
        #expect(runs.map(\.text) == ["let x: ", "Int"])
        #expect(runs.map(\.kind) == [.plain, .typeRef])
    }

    /// XML entity references decode back to their literal characters so
    /// generic syntax like `Array<Int>` displays without escaping.
    @Test func parserDecodesEntities() throws {
        let xml = "<Type>Array&lt;Int&gt;</Type>"
        let runs = try #require(AnnotatedDescriptionParser.parse(xml))
        #expect(runs.count == 1)
        #expect(runs[0].text == "Array<Int>")
        #expect(runs[0].kind == .typeRef)
    }

    /// Unknown tags become transparent — their content joins the surrounding
    /// plain context instead of dropping out of the display.
    @Test func parserTreatsUnknownTagsAsPlain() throws {
        let xml = "hello <mystery>world</mystery>!"
        let runs = try #require(AnnotatedDescriptionParser.parse(xml))
        #expect(runs.count == 1)
        #expect(runs[0].text == "hello world!")
        #expect(runs[0].kind == .plain)
    }

    /// End-to-end: SourceKit-style annotated response flows through
    /// `parse(item:)` and lands on the projected `SwiftCompletionItem` with
    /// both a tag-stripped `description` and a run list.
    @Test func parseItemPopulatesAnnotatedDescription() throws {
        let dict: [String: Any] = [
            "key.kind":        "source.lang.swift.decl.function.free",
            "key.name":        "max(_:_:)",
            "key.description": "<name>max</name>(<callarg.param>a</callarg.param>: <typeid.sys>Int</typeid.sys>, <callarg.param>b</callarg.param>: <typeid.sys>Int</typeid.sys>)",
            "key.sourcetext":  "max(<#T##a: Int##Int#>, <#T##b: Int##Int#>)",
            "key.typename":    "Int"
        ]
        let item = try #require(SourceKitCompletionService.parse(item: dict))

        #expect(item.description == "max(a: Int, b: Int)")
        let runs = try #require(item.annotatedDescription)
        #expect(runs.map(\.kind) == [.declName, .plain, .parameter, .plain, .typeRef, .plain, .parameter, .plain, .typeRef, .plain])
    }

    /// When the response has no annotated markup, `annotatedDescription` is
    /// left nil and `description` is preserved verbatim.
    @Test func parseItemLeavesAnnotationNilForPlainDescription() throws {
        let dict: [String: Any] = [
            "key.kind":        "source.lang.swift.keyword",
            "key.name":        "return",
            "key.description": "return",
            "key.sourcetext":  "return"
        ]
        let item = try #require(SourceKitCompletionService.parse(item: dict))
        #expect(item.annotatedDescription == nil)
        #expect(item.description == "return")
    }
}
