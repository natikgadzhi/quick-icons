//
//  GutterMarkerLogicTests.swift
//  QuickIconsTests
//

import Testing
@testable import QuickIcons

/// Tests for gutter diagnostic marker ordering and per-line dedup.
///
/// Exercises the two rules the gutter pass relies on:
///   - `severityRank` orders error > warning > note with distinct values.
///   - `mostSevereByLine` keeps the highest-severity diagnostic per line.
///
/// The rules live on `TextOffset` so they're testable without standing up a
/// Coordinator or an STTextView.
@MainActor
struct GutterMarkerLogicTests {

    // MARK: - severityRank

    @Test func severityRankOrdersErrorAboveWarningAboveNote() {
        let errorRank = TextOffset.severityRank(.error)
        let warningRank = TextOffset.severityRank(.warning)
        let noteRank = TextOffset.severityRank(.note)

        #expect(errorRank > warningRank)
        #expect(warningRank > noteRank)
    }

    @Test func severityRankValuesAreDistinct() {
        let ranks: Set<Int> = [
            TextOffset.severityRank(.error),
            TextOffset.severityRank(.warning),
            TextOffset.severityRank(.note),
        ]
        #expect(ranks.count == 3)
    }

    // MARK: - mostSevereByLine

    @Test func errorWinsOverWarningAndNoteOnSameLine() {
        let diagnostics: [SwiftDiagnostic] = [
            SwiftDiagnostic(line: 5, column: 1, severity: .warning, message: "w"),
            SwiftDiagnostic(line: 5, column: 1, severity: .error, message: "e"),
            SwiftDiagnostic(line: 5, column: 1, severity: .note, message: "n"),
        ]

        let worst = TextOffset.mostSevereByLine(diagnostics)

        #expect(worst == [5: .error])
    }

    @Test func warningWinsOverNoteOnSameLine() {
        let diagnostics: [SwiftDiagnostic] = [
            SwiftDiagnostic(line: 3, column: 2, severity: .note, message: "n"),
            SwiftDiagnostic(line: 3, column: 4, severity: .warning, message: "w"),
        ]

        let worst = TextOffset.mostSevereByLine(diagnostics)

        #expect(worst == [3: .warning])
    }

    @Test func separateLinesKeepTheirOwnMostSevere() {
        let diagnostics: [SwiftDiagnostic] = [
            SwiftDiagnostic(line: 1, column: 1, severity: .note, message: "n"),
            SwiftDiagnostic(line: 2, column: 1, severity: .warning, message: "w"),
            SwiftDiagnostic(line: 2, column: 1, severity: .error, message: "e"),
            SwiftDiagnostic(line: 3, column: 1, severity: .warning, message: "w2"),
        ]

        let worst = TextOffset.mostSevereByLine(diagnostics)

        #expect(worst == [1: .note, 2: .error, 3: .warning])
    }

    @Test func nonPositiveLineNumbersAreIgnored() {
        let diagnostics: [SwiftDiagnostic] = [
            SwiftDiagnostic(line: 0, column: 1, severity: .error, message: "e"),
            SwiftDiagnostic(line: -3, column: 1, severity: .warning, message: "w"),
        ]

        let worst = TextOffset.mostSevereByLine(diagnostics)

        #expect(worst.isEmpty)
    }
}
