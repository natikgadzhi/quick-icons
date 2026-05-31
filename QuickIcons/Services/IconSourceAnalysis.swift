//
//  IconSourceAnalysis.swift
//  QuickIcons
//

import Foundation

/// Static, syntactic analysis of user-supplied icon source.
///
/// QuickIcons renders an icon by compiling a file into a dylib whose bridge
/// instantiates a single SwiftUI view. `IconSourceAnalysis` decides whether a
/// file can be rendered and which view is the entry point:
///
/// - If a top-level `View` named `IconView` exists, that is the entry point —
///   any number of helper views (e.g. a grain overlay) may coexist with it.
/// - Otherwise, if there is exactly one top-level `View`, that view is used.
/// - Zero top-level views, or several with no `IconView` to disambiguate, is
///   incompatible.
///
/// Detection is purely textual — it never invokes the compiler — so it is cheap
/// enough to run on every file open as well as before each compile.
enum IconSourceAnalysis: Equatable {
    /// The file can be rendered; `viewName` is the view to instantiate.
    case icon(viewName: String)
    /// The file cannot be rendered as an icon; `reason` is user-facing.
    case incompatible(reason: String)

    /// The conventional name of the icon entry-point view.
    static let entryPointName = "IconView"

    /// Matches a top-level `struct Name: conformances {` declaration, capturing
    /// the name (group 1) and the conformance list (group 2). Compiled once.
    private static let structDeclRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:public|private|internal|fileprivate|final|open)\s+)*struct\s+([A-Za-z_]\w*)\s*(?:<[^>]*>)?\s*:\s*([^{]+)\{"#
    )

    /// Matches `View` as a whole word. Compiled once.
    private static let viewWordRegex = try! NSRegularExpression(pattern: #"\bView\b"#)

    /// Classifies `source` into ``icon(viewName:)`` or ``incompatible(reason:)``.
    static func analyze(_ source: String) -> IconSourceAnalysis {
        let views = topLevelViewNames(in: source)

        if views.contains(entryPointName) {
            return .icon(viewName: entryPointName)
        }

        switch views.count {
        case 0:
            return .incompatible(
                reason: "No SwiftUI view found. Add a top-level icon view, e.g. "
                    + "`struct IconView: View { var size: CGFloat }`."
            )
        case 1:
            return .icon(viewName: views[0])
        default:
            return .incompatible(
                reason: "Found \(views.count) top-level views (\(views.joined(separator: ", "))). "
                    + "Name the one to render as the icon `IconView`."
            )
        }
    }

    /// Names of top-level `struct`s declared as conforming to SwiftUI's `View`.
    ///
    /// Brace depth is tracked so only file-scope declarations count, and `View`
    /// is matched as a whole word in the conformance list so types like
    /// `NSViewRepresentable` or `PreviewProvider` do not false-positive.
    static func topLevelViewNames(in source: String) -> [String] {
        var names: [String] = []
        var depth = 0

        for rawLine in source.components(separatedBy: "\n") {
            let line = stripComment(rawLine)

            // A struct declaration's opening brace sits on its own line, so a
            // top-level declaration is one seen while depth is still 0.
            if depth == 0 {
                let range = NSRange(line.startIndex..., in: line)
                if let match = structDeclRegex.firstMatch(in: line, range: range),
                   let nameRange = Range(match.range(at: 1), in: line),
                   let conformanceRange = Range(match.range(at: 2), in: line),
                   conformsToView(String(line[conformanceRange])) {
                    names.append(String(line[nameRange]))
                }
            }

            // Single pass over the line: net brace delta, clamped at zero.
            for char in line where char == "{" || char == "}" {
                depth += char == "{" ? 1 : -1
            }
            depth = max(depth, 0)
        }

        return names
    }

    /// Drops a trailing `//` line comment so braces/keywords inside comments are
    /// ignored. Good enough for the icon-source heuristic; not a full lexer.
    private static func stripComment(_ line: String) -> String {
        guard let commentRange = line.range(of: "//") else { return line }
        return String(line[..<commentRange.lowerBound])
    }

    /// Whether a conformance list contains `View` as a whole word.
    private static func conformsToView(_ conformances: String) -> Bool {
        let range = NSRange(conformances.startIndex..., in: conformances)
        return viewWordRegex.firstMatch(in: conformances, range: range) != nil
    }
}
