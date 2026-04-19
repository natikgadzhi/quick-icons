import Foundation
import SourceKittenFramework

/// A single code-completion suggestion, projected from SourceKit's
/// `source.request.codecomplete` response into a small value type that the
/// UI layer can consume without depending on SourceKittenFramework.
///
/// `sourcetext` contains the raw SourceKit insertion template, including
/// `<#placeholder#>` markers for function arguments. Stage 3 will translate
/// those into STTextView snippet placeholders; stage 1 just preserves them.
public struct SwiftCompletionItem: Sendable, Equatable {
    public let name: String
    public let description: String
    public let sourcetext: String
    public let kind: CompletionKind
    public let typeName: String?

    public init(
        name: String,
        description: String,
        sourcetext: String,
        kind: CompletionKind,
        typeName: String?
    ) {
        self.name = name
        self.description = description
        self.sourcetext = sourcetext
        self.kind = kind
        self.typeName = typeName
    }
}

/// Closed set of completion kinds we render in the UI. SourceKit emits many
/// fine-grained kind UIDs (free function vs. instance method vs. static method,
/// etc.); we collapse them into the categories that map to distinct SF Symbols.
public enum CompletionKind: String, Sendable, Equatable, CaseIterable {
    case function
    case method
    case `class`
    case `struct`
    case `enum`
    case enumCase
    case `protocol`
    case `typealias`
    case property
    case localVar
    case globalVar
    case keyword
    case module
    case other

    /// SF Symbol name used by stage 3 for the completion popup icon.
    public var sfSymbolName: String {
        switch self {
        case .function:   return "f.square"
        case .method:     return "m.square"
        case .class:      return "c.square"
        case .struct:     return "s.square"
        case .enum:       return "e.square"
        case .enumCase:   return "circle.hexagongrid"
        case .protocol:   return "p.square"
        case .typealias:  return "t.square"
        case .property:   return "circle.dotted"
        case .localVar:   return "v.square"
        case .globalVar:  return "g.square"
        case .keyword:    return "k.square"
        case .module:     return "shippingbox"
        case .other:      return "questionmark.square"
        }
    }

    /// Maps a SourceKit `key.kind` UID (e.g. `source.lang.swift.decl.function.method.instance`)
    /// to our closed set. Unknown kinds bucket into `.other`.
    public static func from(sourceKitKind raw: String) -> CompletionKind {
        // Keyword and module kinds come first — they are distinct top-level UIDs.
        if raw.contains("keyword") { return .keyword }
        if raw.hasSuffix(".module") { return .module }

        // Decl kinds — order matters because we match on the most specific suffix.
        if raw.contains(".enumelement") || raw.contains(".enumcase") { return .enumCase }
        if raw.contains(".function.method") || raw.contains(".function.constructor") || raw.contains(".function.destructor") || raw.contains(".function.subscript") {
            return .method
        }
        if raw.contains(".function.accessor") { return .property }
        if raw.contains(".function") { return .function }
        if raw.contains(".class") { return .class }
        if raw.contains(".struct") { return .struct }
        if raw.contains(".enum") { return .enum }
        if raw.contains(".protocol") { return .protocol }
        if raw.contains(".typealias") || raw.contains(".associatedtype") { return .typealias }
        if raw.contains(".var.instance") || raw.contains(".var.static") || raw.contains(".var.class") {
            return .property
        }
        if raw.contains(".var.local") || raw.contains(".var.parameter") { return .localVar }
        if raw.contains(".var.global") { return .globalVar }
        if raw.contains(".var") { return .property }
        return .other
    }
}

/// Abstraction over the SourceKit code-completion request, injected into the
/// service so tests can supply canned responses without spawning sourcekitd.
///
/// The runner returns the raw `key.results` array, each element a
/// `[String: Any]` dictionary matching SourceKittenFramework's
/// `CodeCompletionItem.parse` input. Using `[[String: Any]]` keeps the protocol
/// independent of SourceKitten's `SourceKitRepresentable`.
public protocol CompletionRequestRunning: Sendable {
    func run(source: String, offset: Int) async throws -> [[String: Any]]
}

/// Default runner — writes `source` to a temp file and issues
/// `source.request.codecomplete` via SourceKittenFramework.
public struct SourceKittenRunner: CompletionRequestRunning {

    private static let cachedSDKPath: String? = Self.resolveSDKPath()

    public init() {}

    public func run(source: String, offset: Int) async throws -> [[String: Any]] {
        let tmpURL = try writeTempFile(source)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let path = tmpURL.path
        let args = buildCompilerArgs(path: path, sdkPath: Self.cachedSDKPath)
        let request = Request.codeCompletionRequest(
            file: path,
            contents: source,
            offset: ByteCount(offset),
            arguments: args
        )
        let response = try await request.asyncSend()
        guard let results = response["key.results"] as? [[String: SourceKitRepresentable]] else {
            return []
        }
        // Project each item dictionary into [String: Any] so downstream code
        // does not depend on SourceKitRepresentable.
        return results.map { dict in
            dict.mapValues { $0 as Any }
        }
    }

    private func writeTempFile(_ source: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SourceKitCompletion-\(UUID().uuidString).swift")
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func resolveSDKPath() -> String? {
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
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func buildCompilerArgs(path: String, sdkPath: String?) -> [String] {
        var args: [String] = [path]
        if let sdk = sdkPath {
            args += ["-sdk", sdk]
        }
        args += ["-target", "arm64-apple-macosx15.0"]
        args += ["-module-name", "UserIcon"]
        return args
    }
}

/// Requests code-completion suggestions from SourceKit for a Swift source
/// string at a given UTF-8 byte offset. Mirrors `SourceKitDiagnosticsService`
/// in structure (injectable request runner, task-cancellable async API) but
/// exposes a typed `[SwiftCompletionItem]` result.
///
/// The service itself is stateless and does not debounce — callers (the editor
/// coordinator) apply a 200 ms debounce before invoking `complete(source:offset:)`.
public final class SourceKitCompletionService: Sendable {

    private let runner: any CompletionRequestRunning

    public init(runner: any CompletionRequestRunning = SourceKittenRunner()) {
        self.runner = runner
    }

    /// Returns completion suggestions for `source` at `offset` (UTF-8 byte
    /// offset, matching SourceKit's convention). Throws if the underlying
    /// runner fails; returns `[]` for empty input.
    ///
    /// Supports cancellation — if the enclosing `Task` is cancelled before or
    /// after the runner finishes, this method throws `CancellationError`.
    public func complete(source: String, offset: Int) async throws -> [SwiftCompletionItem] {
        guard !source.isEmpty else { return [] }
        try Task.checkCancellation()

        let raw = try await runner.run(source: source, offset: offset)
        try Task.checkCancellation()

        return raw.compactMap { Self.parse(item: $0) }
    }

    /// Projects one SourceKit result dictionary into a `SwiftCompletionItem`.
    /// Returns `nil` if the entry is missing the minimum fields.
    static func parse(item dict: [String: Any]) -> SwiftCompletionItem? {
        guard let kindUID = dict["key.kind"] as? String else { return nil }
        let name = (dict["key.name"] as? String) ?? ""
        let description = (dict["key.description"] as? String) ?? name
        let sourcetext = (dict["key.sourcetext"] as? String) ?? name
        let typeName = dict["key.typename"] as? String

        // Skip entries with no usable name — SourceKit occasionally returns
        // placeholder results with only a kind.
        guard !name.isEmpty || !description.isEmpty else { return nil }

        return SwiftCompletionItem(
            name: name.isEmpty ? description : name,
            description: description,
            sourcetext: sourcetext,
            kind: CompletionKind.from(sourceKitKind: kindUID),
            typeName: typeName
        )
    }
}
