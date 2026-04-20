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

    /// Structured runs parsed from SourceKit's annotated description, used to
    /// render the completion popup row with per-span foreground colors pulled
    /// from the editor's Xcode theme. `nil` when SourceKit did not supply an
    /// annotated form (typically: completion runs using a sourcekitd that did
    /// not opt into `key.codecomplete.annotateddescription`) — callers should
    /// fall back to rendering `description` as a single plain run.
    public let annotatedDescription: [AnnotatedRun]?

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
        typeName: String?,
        annotatedDescription: [AnnotatedRun]? = nil
    ) {
        self.name = name
        self.description = description
        self.sourcetext = sourcetext
        self.kind = kind
        self.typeName = typeName
        self.annotatedDescription = annotatedDescription
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

// MARK: - Annotated description

/// A contiguous span of a completion row's display text, tagged with its
/// semantic role. The view layer maps each `kind` to a color in
/// `Theme.xcode` so completion rows render with the same palette as the
/// editor — types in purple, keywords in magenta, numerics, etc. — and
/// re-resolve automatically when the user toggles light/dark mode.
public struct AnnotatedRun: Sendable, Equatable {
    public let text: String
    public let kind: AnnotationKind

    public init(text: String, kind: AnnotationKind) {
        self.text = text
        self.kind = kind
    }
}

/// The semantic role of an `AnnotatedRun`. The raw value is the Theme.xcode
/// token name used to look up the run's foreground color — kept in sync with
/// the palette declared in `XcodeColorTheme.swift`. Values not present in the
/// theme dictionary fall back to `plain`.
public enum AnnotationKind: String, Sendable, Equatable {
    /// Declaration name (function, variable, type identifier being declared).
    /// Uses the theme's `function.call` token so the symbol being completed
    /// gets the same blue/teal accent Xcode uses for user function refs.
    case declName   = "function.call"
    /// Parameter label or parameter name within a signature.
    case parameter  = "parameter"
    /// Type reference (`Int`, `String`, generic parameter).
    case typeRef    = "type"
    /// Swift keyword (`let`, `func`, `return`, …).
    case keyword    = "keyword"
    /// Numeric, string, or boolean literal.
    case literal    = "number"
    /// Punctuation/operator/whitespace — no special color.
    case plain      = "plain"
}

/// Parses SourceKit's annotated description / type XML into a run list.
///
/// SourceKit produces two related tag vocabularies. The completion request
/// (with `key.codecomplete.annotateddescription` enabled) emits a compact
/// subset — typically `<name>`, `<keyword>`, `<typeid.sys>` / `<typeid.user>`,
/// `<callarg.param>` / `<callarg.type>`, `<paramname>` — while cursor-info
/// emits the richer `<Declaration><Type>…</Type></Declaration>` form found in
/// `key.annotated_decl`. The parser handles both by mapping tag names to
/// `AnnotationKind` categories and treating unknown tags as transparent
/// containers (their text content becomes `.plain` runs, preserving
/// whitespace and surrounding punctuation).
///
/// Returns `nil` when the input contains no XML-like tags — callers use this
/// to fall back to rendering the plain `description` string. Entity-escaped
/// characters (`&lt;`, `&gt;`, `&amp;`, `&quot;`, `&apos;`) are decoded.
public enum AnnotatedDescriptionParser {

    public static func parse(_ xml: String) -> [AnnotatedRun]? {
        // Fast reject: a string with no `<` cannot possibly be tagged.
        guard xml.contains("<") else { return nil }

        var runs: [AnnotatedRun] = []
        var tagStack: [AnnotationKind] = []
        var scanner = xml.startIndex

        // Coalesce adjacent runs of the same kind so the label renders as
        // one attributed segment per color band rather than one per tag.
        func appendText(_ text: String, kind: AnnotationKind) {
            guard !text.isEmpty else { return }
            if let last = runs.last, last.kind == kind {
                runs[runs.count - 1] = AnnotatedRun(text: last.text + text, kind: kind)
            } else {
                runs.append(AnnotatedRun(text: text, kind: kind))
            }
        }

        while scanner < xml.endIndex {
            if xml[scanner] == "<" {
                // Find the closing `>` for this tag.
                guard let tagEnd = xml[scanner...].firstIndex(of: ">") else {
                    // Malformed — treat the rest as literal text.
                    appendText(decodeEntities(String(xml[scanner...])),
                               kind: tagStack.last ?? .plain)
                    break
                }
                let rawTag = xml[xml.index(after: scanner)..<tagEnd]
                let isClosing = rawTag.first == "/"
                let nameStart = isClosing ? xml.index(after: rawTag.startIndex) : rawTag.startIndex
                // Tag name ends at first whitespace (attribute boundary) or
                // at the tag's end. Self-closing tags (`<foo/>`) are rare in
                // SourceKit output but handled by treating them as a no-op.
                let nameEnd = rawTag[nameStart...].firstIndex(where: { $0 == " " || $0 == "\t" }) ?? rawTag.endIndex
                let tagName = String(rawTag[nameStart..<nameEnd])
                let isSelfClosing = rawTag.last == "/"

                if isClosing {
                    _ = tagStack.popLast()
                } else if !isSelfClosing {
                    tagStack.append(kind(forTag: tagName))
                }

                scanner = xml.index(after: tagEnd)
            } else {
                // Accumulate text up to the next `<`.
                let textEnd = xml[scanner...].firstIndex(of: "<") ?? xml.endIndex
                let segment = xml[scanner..<textEnd]
                let kind = tagStack.last ?? .plain
                appendText(decodeEntities(String(segment)), kind: kind)
                scanner = textEnd
            }
        }

        return runs.isEmpty ? nil : runs
    }

    /// Maps a SourceKit annotation tag name to an `AnnotationKind`. Tags we
    /// don't recognize bucket into `.plain` so their text content still
    /// renders — we just don't give them a dedicated color.
    static func kind(forTag name: String) -> AnnotationKind {
        switch name {
        // Completion annotated description tags.
        case "name", "decl.name":
            return .declName
        case "keyword", "syntaxtype.keyword", "Keyword":
            return .keyword
        case "typeid.sys", "typeid.user",
             "Type",
             "decl.var.type", "decl.function.returntype",
             "ref.struct", "ref.class", "ref.enum", "ref.protocol",
             "ref.typealias", "ref.generic_type_param",
             "decl.generic_type_param", "decl.generic_type_param.name":
            return .typeRef
        case "callarg.param", "callarg.label", "paramname", "Parameter",
             "decl.var.parameter", "decl.var.parameter.name",
             "decl.var.parameter.argument_label":
            return .parameter
        case "Literal", "number", "boolean", "string":
            return .literal
        // Container tags — their text children get the containing context.
        case "Declaration", "decl.function.free", "decl.function.method.instance",
             "decl.function.method.static", "decl.var.instance", "decl.var.static",
             "decl.struct", "decl.class", "decl.enum", "decl.protocol":
            return .plain
        default:
            return .plain
        }
    }

    /// Decodes the five XML entity references SourceKit uses. Numeric
    /// entities (`&#xNN;`) are rare in SourceKit output and left unhandled —
    /// worst case, a stray `&amp;` displays verbatim, which is acceptable.
    static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        return input
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
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

    private static let cachedSDKPath: String? = Self.resolveSDKPath()

    public init() {}

    public func run(source: String, offset: Int) async throws -> [[String: Any]] {
        let tmpURL = try writeTempFile(source)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let path = tmpURL.path
        let args = buildCompilerArgs(path: path, sdkPath: Self.cachedSDKPath)
        // Mirror SourceKittenFramework's `codeCompletionRequest` shape but add
        // `key.codecomplete.annotateddescription` so sourcekitd wraps each
        // result's `key.description` in tagged spans (`<keyword>`, `<typeid.sys>`,
        // `<callarg.param>`, …) that the UI can color per Theme.xcode.
        //
        // Opting in is additive: older toolchains that don't recognize the key
        // fall back to plain descriptions, and the parser treats untagged
        // strings as a single plain run — no behavior regression.
        let request: Request = .customRequest(request: [
            "key.request":                            UID("source.request.codecomplete"),
            "key.name":                               path,
            "key.sourcefile":                         path,
            "key.sourcetext":                         source,
            "key.offset":                             Int64(offset),
            "key.compilerargs":                       args,
            "key.codecomplete.annotateddescription":  1
        ])
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
        let rawDescription = (dict["key.description"] as? String) ?? name
        let sourcetext = (dict["key.sourcetext"] as? String) ?? name
        let typeName = dict["key.typename"] as? String

        // Skip entries with no usable name — SourceKit occasionally returns
        // placeholder results with only a kind.
        guard !name.isEmpty || !rawDescription.isEmpty else { return nil }

        // When SourceKit emits an annotated description (XML-like tags), parse
        // it into typed runs the view layer colors with Theme.xcode. Strip the
        // tags from the description we store — that field is also used for
        // identity (`SwiftCompletionListItem.id`), so keeping it plain avoids
        // spurious churn when annotation opt-in toggles across runs.
        let annotated = AnnotatedDescriptionParser.parse(rawDescription)
        let description: String
        if let annotated {
            description = annotated.map(\.text).joined()
        } else {
            description = rawDescription
        }

        return SwiftCompletionItem(
            name: name.isEmpty ? description : name,
            description: description,
            sourcetext: sourcetext,
            kind: CompletionKind.from(sourceKitKind: kindUID),
            typeName: typeName,
            annotatedDescription: annotated
        )
    }
}
