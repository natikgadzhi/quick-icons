//
//  TextOffset.swift
//  QuickIcons
//
//  Shared pure helpers that convert between the offset spaces the editor
//  stack juggles: UTF-16 code units (what NSTextLayoutManager.offset returns),
//  UTF-8 byte offsets (what SourceKit expects), and 1-based line numbers.
//
//  Kept as a namespace of `static` functions so the logic is trivially
//  testable without standing up a Coordinator, and both DiagnosticsCoordinator
//  and CompletionCoordinator can share the conversions without a dependency
//  between them.
//

import Foundation

/// Pure offset-conversion helpers shared by the editor coordinators.
///
/// Every helper is deterministic, side-effect free, and MainActor-agnostic —
/// safe to call from anywhere the caller has already hopped to the right
/// isolation domain.
enum TextOffset {

    /// Converts a UTF-16 code-unit offset (what `NSTextLayoutManager.offset`
    /// returns) into the UTF-8 byte offset SourceKit expects. Returns the
    /// total UTF-8 byte count when `utf16Offset` falls past the end of the
    /// string or lands mid-surrogate — SourceKit tolerates an offset at EOF.
    static func utf8ByteOffset(forUTF16Offset utf16Offset: Int, in source: String) -> Int {
        guard utf16Offset > 0 else { return 0 }
        guard let endIndex = source.utf16.index(
            source.utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: source.utf16.endIndex
        ) else {
            return source.utf8.count
        }
        guard let strIndex = endIndex.samePosition(in: source) else {
            return source.utf8.count
        }
        guard let utf8Index = strIndex.samePosition(in: source.utf8) else {
            return source.utf8.count
        }
        return source.utf8.distance(from: source.utf8.startIndex, to: utf8Index)
    }

    /// Returns the UTF-16 offset of the start of `line` (1-based) within `source`.
    /// Returns `-1` when the line is out of range.
    static func utf16Offset(forLine line: Int, in source: String) -> Int {
        guard line >= 1 else { return -1 }

        var currentLine = 1
        var utf16Count = 0
        for char in source {
            if currentLine == line { break }
            if char == "\n" { currentLine += 1 }
            utf16Count += char.utf16.count
        }

        guard currentLine == line else { return -1 }
        return utf16Count
    }

    /// Returns the length (in UTF-16 code units) of the identifier prefix
    /// ending at `endingAtUTF16Offset` inside `source`. Used to decide how
    /// much of the user's partial word to replace on completion insertion.
    /// An identifier character is `[A-Za-z0-9_]`; mirrors what the SourceKit
    /// completion request considers a prefix.
    static func identifierPrefixLength(in source: String, endingAtUTF16Offset offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        let utf16 = source.utf16
        guard let endIndex = utf16.index(
            utf16.startIndex,
            offsetBy: offset,
            limitedBy: utf16.endIndex
        ) else {
            return 0
        }
        var count = 0
        var cursor = endIndex
        while cursor > utf16.startIndex {
            let prev = utf16.index(before: cursor)
            let unit = utf16[prev]
            // Fast path: only ASCII identifier characters count as prefix.
            let isIdent = (unit >= 0x30 && unit <= 0x39)          // 0-9
                || (unit >= 0x41 && unit <= 0x5A)                 // A-Z
                || (unit >= 0x61 && unit <= 0x7A)                 // a-z
                || unit == 0x5F                                   // _
            if !isIdent { break }
            count += 1
            cursor = prev
        }
        return count
    }
}

// MARK: - Diagnostic severity helpers

extension TextOffset {
    /// Returns a mapping of 1-based line number → most-severe severity for that
    /// line among `diagnostics`. Diagnostics with non-positive line numbers are
    /// ignored. Exposed here so the dedup rule is directly testable.
    static func mostSevereByLine(_ diagnostics: [SwiftDiagnostic]) -> [Int: SwiftDiagnostic.Severity] {
        var worstByLine: [Int: SwiftDiagnostic.Severity] = [:]
        for diagnostic in diagnostics where diagnostic.line >= 1 {
            let current = worstByLine[diagnostic.line]
            if current == nil || severityRank(diagnostic.severity) > severityRank(current!) {
                worstByLine[diagnostic.line] = diagnostic.severity
            }
        }
        return worstByLine
    }

    static func severityRank(_ severity: SwiftDiagnostic.Severity) -> Int {
        switch severity {
        case .error: return 2
        case .warning: return 1
        case .note: return 0
        }
    }
}
