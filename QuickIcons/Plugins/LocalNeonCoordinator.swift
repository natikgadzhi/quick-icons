import Cocoa
import STTextView
import STTextKitPlus
import STPluginNeon
import Neon
import TreeSitterClient
import SwiftTreeSitter
import TreeSitterResource
import Rearrange

/// Mirrors `STPluginNeonAppKit.Coordinator` but loads BOTH `highlights.scm`
/// AND `locals.scm` into its token provider. See `LocalNeonPlugin` for why
/// this exists as a vendored copy rather than a patch against upstream.
@MainActor
final class LocalNeonCoordinator {
    private(set) var highlighter: Neon.Highlighter?
    private let language: TreeSitterLanguage
    private let tsLanguage: SwiftTreeSitter.Language
    private let tsClient: TreeSitterClient
    private var prevViewportRange: NSTextRange?

    init(textView: STTextView, theme: Theme, language: TreeSitterLanguage) {
        self.language = language
        tsLanguage = Language(language: language.parser)

        // TreeSitterClient can theoretically throw on construction, but in
        // practice only when the language pointer is nil — which can't happen
        // for the grammars shipped by TreeSitterResource. Upstream uses the
        // same `try!`.
        tsClient = try! TreeSitterClient(language: tsLanguage) { codePointIndex in
            guard let location = textView.textContentManager.location(at: codePointIndex),
                  let position = textView.textContentManager.position(location)
            else {
                return .zero
            }
            return Point(row: position.row, column: position.column)
        }

        tsClient.invalidationHandler = { [weak self] indexSet in
            self?.highlighter?.invalidate(.set(indexSet))
        }

        // Default font from theme's "plain" slot (mirrors upstream).
        textView.font = theme.font(forToken: "plain") ?? textView.font

        // Attribute provider — identical to upstream. Colors and fonts come
        // from the Theme, falling back to the "plain" slot when a token name
        // isn't explicitly listed (e.g. the `definition.function` and
        // `local.reference` captures we newly emit from locals.scm).
        let systemInterface = LocalNeonSystemInterface(textView: textView) { neonToken in
            var attributes: [NSAttributedString.Key: Any] = [:]
            attributes[.font] = textView.font

            let tokenName = TokenName(neonToken.name)
            if let themeColor = theme.color(forToken: tokenName) {
                attributes[.foregroundColor] = themeColor
                if let themeFont = theme.font(forToken: tokenName) {
                    attributes[.font] = themeFont
                }
            } else if let themeDefaultColor = theme.color(forToken: "plain") {
                attributes[.foregroundColor] = themeDefaultColor
                if let themeFont = theme.font(forToken: tokenName) {
                    attributes[.font] = themeFont
                }
            }

            return attributes.isEmpty ? nil : attributes
        }

        highlighter = Neon.Highlighter(
            textInterface: systemInterface,
            tokenProvider: makeTokenProvider(textContentManager: textView.textContentManager)
        )

        // Initial parse covering the whole document (mirrors upstream).
        let fullRange = NSRange(textView.textContentManager.documentRange, in: textView.textContentManager)
        let initialText = textView.textContentManager.attributedString(in: nil)?.string ?? ""
        tsClient.willChangeContent(in: fullRange)
        tsClient.didChangeContent(
            in: fullRange,
            delta: textView.textContentManager.length,
            limit: textView.textContentManager.length,
            readHandler: Parser.readFunction(for: initialText),
            completionHandler: {}
        )
    }

    // MARK: - Token provider (highlights + locals)

    /// Builds a `TokenProvider` that combines the `highlights.scm` stream
    /// with extra tokens produced by `locals.scm`.
    ///
    /// Upstream only loads `highlightQueryURL`, so scope-aware captures
    /// (e.g. `@definition.function`, `@definition.import`) that Plugin-Neon
    /// ships in `TreeSitterSwiftQueries/locals.scm` are never emitted. Here
    /// we load both, execute them against the same parse state, and append
    /// the locals capture names to the token list so the theme can give
    /// them distinct colors.
    ///
    /// Capture names coming from `locals.scm` are passed through unchanged —
    /// e.g. `definition.function`, `definition.import`. A special case is
    /// `local.scope`: that capture names a whole region (a statement block,
    /// a function body) rather than an identifier, so emitting it as a token
    /// would recolor the entire scope. We drop any capture whose top-level
    /// component is `local.scope` before feeding the list to Neon.
    private func makeTokenProvider(textContentManager: NSTextContentManager) -> Neon.TokenProvider? {
        guard let highlightsURL = language.highlightQueryURL,
              let highlightsQuery = try? tsLanguage.query(contentsOf: highlightsURL) else {
            return nil
        }

        let textProvider: SwiftTreeSitter.Predicate.TextProvider = { range, _ in
            guard !range.isEmpty else { return nil }
            return textContentManager
                .attributedString(in: NSTextRange(range, provider: textContentManager))?
                .string
        }

        // locals.scm is optional — only a handful of grammars ship one. Fall
        // back to highlights-only when the language doesn't expose it.
        let localsQuery: SwiftTreeSitter.Query?
        if let localsURL = language.localsQueryURL,
           let query = try? tsLanguage.query(contentsOf: localsURL) {
            localsQuery = query
        } else {
            localsQuery = nil
        }

        let baseProvider = tsClient.tokenProvider(with: highlightsQuery, textProvider: textProvider)

        guard let localsQuery else {
            // Nothing to merge — hand back the stock highlights provider.
            return baseProvider
        }

        // Wrap the base provider so we can splice locals tokens into each
        // batch after the highlights query resolves. `tsClient.tokenProvider`
        // runs asynchronously; we run the locals query synchronously on the
        // same main queue afterwards, which is safe because the parse state
        // has already settled by the time the highlights completion fires.
        let client = tsClient
        return { range, completionHandler in
            baseProvider(range) { result in
                switch result {
                case .failure(let error):
                    completionHandler(.failure(error))
                case .success(var application):
                    let localsTokens = Self.localsTokens(
                        range: range,
                        query: localsQuery,
                        client: client
                    )
                    if !localsTokens.isEmpty {
                        // Append locals tokens after highlights tokens. Neon's
                        // Highlighter applies attributes in token-array order
                        // during the final attribute pass, so later tokens
                        // layer on top of earlier ones for overlapping ranges.
                        application = TokenApplication(
                            tokens: application.tokens + localsTokens,
                            range: application.range,
                            action: application.action
                        )
                    }
                    completionHandler(.success(application))
                }
            }
        }
    }

    /// Runs the locals query synchronously for `range` and converts the
    /// resulting `NamedRange`s into Neon `Token`s. `@local.scope` captures
    /// are filtered out because they cover whole statement blocks rather
    /// than identifiers.
    private static func localsTokens(
        range: NSRange,
        query: SwiftTreeSitter.Query,
        client: TreeSitterClient
    ) -> [Neon.Token] {
        guard case .success(let cursor) = client.executeQuerySynchronously(query, in: range) else {
            return []
        }
        let namedRanges = cursor.locals()
        return namedRanges.compactMap { named in
            // Drop region captures — they cover entire scopes, not identifiers.
            guard named.nameComponents.first != "local.scope" else { return nil }
            guard !named.range.byteRange.isEmpty else { return nil }
            return Neon.Token(name: named.name, range: named.range)
        }
    }

    // MARK: - Event hooks (called from LocalNeonPlugin.setUp)

    func updateViewportRange(_ range: NSTextRange?) {
        if range != prevViewportRange {
            highlighter?.visibleContentDidChange()
        }
        prevViewportRange = range
    }

    func willChangeContent(in range: NSRange) {
        tsClient.willChangeContent(in: range)
    }

    func didChangeContent(_ textContentManager: NSTextContentManager, in range: NSRange, delta: Int, limit: Int) {
        if let str = textContentManager.attributedString(in: nil)?.string {
            let readFunction = Parser.readFunction(for: str)
            tsClient.didChangeContent(
                in: range,
                delta: delta,
                limit: limit,
                readHandler: readFunction,
                completionHandler: {}
            )
        }
    }
}

// MARK: - Text system interface

/// Reimplementation of the internal `STTextViewSystemInterface` from
/// `STPluginNeonAppKit`. Upstream keeps this type package-internal, so our
/// vendored coordinator ships its own copy. Behavior is identical: clear
/// rendering attributes in the requested range and apply per-token attributes
/// produced by the theme lookup.
private final class LocalNeonSystemInterface: Neon.TextSystemInterface {
    typealias AttributeProvider = (Neon.Token) -> [NSAttributedString.Key: Any]?

    private let textView: STTextView
    private let attributeProvider: AttributeProvider

    init(textView: STTextView, attributeProvider: @escaping AttributeProvider) {
        self.textView = textView
        self.attributeProvider = attributeProvider
    }

    func clearStyle(in range: NSRange) {
        guard let textRange = NSTextRange(range, in: textView.textContentManager) else {
            assertionFailure()
            return
        }
        textView.textLayoutManager.removeRenderingAttribute(.foregroundColor, for: textRange)
        textView.addAttributes([.font: textView.font], range: range)
    }

    func applyStyle(to token: Neon.Token) {
        guard let attrs = attributeProvider(token),
              let textRange = NSTextRange(token.range, in: textView.textContentManager) else {
            return
        }
        for attr in attrs {
            if attr.key == .foregroundColor {
                textView.textLayoutManager.addRenderingAttribute(.foregroundColor, value: attr.value, for: textRange)
            } else {
                textView.addAttributes([attr.key: attr.value], range: token.range)
            }
        }
    }

    var length: Int {
        textView.textContentManager.length
    }

    var visibleRange: NSRange {
        guard let viewportRange = textView.textLayoutManager.textViewportLayoutController.viewportRange else {
            return .zero
        }
        return NSRange(viewportRange, provider: textView.textContentManager)
    }
}
