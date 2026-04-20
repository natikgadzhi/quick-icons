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

    /// The SourceKit `sourcetext` stripped of `<#...#>` placeholder markers —
    /// suitable for plain-text insertion into an editor that does not support
    /// snippet placeholders.
    ///
    /// SourceKit emits two placeholder shapes:
    ///   * Typed:  `<#T##label##Type#>` — we surface `label`.
    ///   * Simple: `<#label#>`          — we surface `label`.
    ///
    /// Everything outside the markers is passed through verbatim so operators,
    /// parentheses, commas, etc. remain intact.
    ///
    /// Computed once at init from `sourcetext` and cached so repeated reads
    /// (popup display + insertion) don't re-parse the template.
    public let plainInsertText: String

    /// UTF-16 range of the first placeholder inside `plainInsertText`, or
    /// `nil` when the sourcetext contains no placeholders. Callers use this to
    /// position the caret / selection so the user can immediately type over
    /// the first argument.
    public let firstPlaceholderUTF16Range: Range<Int>?

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
        let stripped = Self.strippedSourceText(sourcetext)
        self.plainInsertText = stripped.text
        self.firstPlaceholderUTF16Range = stripped.firstPlaceholder
    }

    /// Parses `sourcetext`, returning the plain visible text and the UTF-16
    /// range of the first placeholder within that text.
    static func strippedSourceText(_ sourcetext: String) -> (text: String, firstPlaceholder: Range<Int>?) {
        var output = ""
        var firstPlaceholder: Range<Int>?
        var utf16Offset = 0

        var remaining = Substring(sourcetext)
        while let openRange = remaining.range(of: "<#") {
            // Append the literal prefix before the placeholder opener.
            let prefix = remaining[remaining.startIndex..<openRange.lowerBound]
            output.append(contentsOf: prefix)
            utf16Offset += prefix.utf16.count

            let afterOpen = remaining[openRange.upperBound...]
            guard let closeRange = afterOpen.range(of: "#>") else {
                // Unterminated placeholder — treat the rest as literal text.
                output.append(contentsOf: remaining[openRange.lowerBound...])
                break
            }

            let body = afterOpen[afterOpen.startIndex..<closeRange.lowerBound]
            let visible = visibleLabel(for: body)
            let startUTF16 = utf16Offset
            output.append(contentsOf: visible)
            utf16Offset += visible.utf16.count
            if firstPlaceholder == nil && !visible.isEmpty {
                firstPlaceholder = startUTF16..<utf16Offset
            }

            remaining = afterOpen[closeRange.upperBound...]
        }

        output.append(contentsOf: remaining)
        return (output, firstPlaceholder)
    }

    /// Extracts the visible label from a placeholder body.
    /// Typed form `T##label##Type` → `label`; simple form `label` → `label`.
    private static func visibleLabel(for body: Substring) -> Substring {
        if body.hasPrefix("T##") {
            // Drop the leading "T##" then take everything up to the next "##".
            let afterT = body.dropFirst(3)
            if let sep = afterT.range(of: "##") {
                return afterT[afterT.startIndex..<sep.lowerBound]
            }
            return afterT
        }
        return body
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
    case literal
    case other

    /// SF Symbol name used by stage 3 for the completion popup icon.
    ///
    /// All names are standard SF Symbols shipped with macOS: the `{letter}.square`
    /// family, `questionmark.square`, `number.square`, `shippingbox`, and
    /// `circle.*`. Tests ensure every case resolves to a non-empty symbol name;
    /// missing symbols would render as a blank icon rather than crash.
    public var sfSymbolName: String {
        switch self {
        case .function:   return "f.square"
        case .method:     return "m.square"
        case .class:      return "c.square"
        case .struct:     return "s.square"
        case .enum:       return "e.square"
        case .enumCase:   return "e.square"
        case .protocol:   return "p.square"
        case .typealias:  return "t.square"
        case .property:   return "v.square"
        case .localVar:   return "v.square"
        case .globalVar:  return "v.square"
        case .keyword:    return "k.square"
        case .module:     return "shippingbox"
        case .literal:    return "number.square"
        case .other:      return "questionmark.square"
        }
    }

    /// Maps a SourceKit `key.kind` UID (e.g. `source.lang.swift.decl.function.method.instance`)
    /// to our closed set. Unknown kinds bucket into `.other`.
    public static func from(sourceKitKind raw: String) -> CompletionKind {
        // Keyword, module, and literal kinds come first — they are distinct
        // top-level UIDs that don't fit the `.decl.*` hierarchy below.
        if raw.contains("keyword") { return .keyword }
        if raw.hasSuffix(".module") { return .module }
        if raw.contains(".literal") { return .literal }

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

    public init() {}

    public func run(source: String, offset: Int) async throws -> [[String: Any]] {
        let tmpURL = try writeTempFile(source)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Resolve the SDK path lazily via the shared actor-backed cache so
        // the first completion request doesn't spawn `xcrun` on MainActor.
        let sdkPath = await SDKPathCache.shared.path()

        let path = tmpURL.path
        let args = buildCompilerArgs(path: path, sdkPath: sdkPath)
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

    private func buildCompilerArgs(path: String, sdkPath: String?) -> [String] {
        var args: [String] = [path]
        if let sdk = sdkPath {
            args += ["-sdk", sdk]
        }
        args += ["-target", BuildEnvironment.targetTriple]
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
