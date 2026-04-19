//
//  AutoIndentTests.swift
//  QuickIconsTests
//

import Testing
@testable import QuickIcons

/// Tests for `AutoIndent.indent(source:insertionPointUTF16Offset:)`.
///
/// The helper is intentionally decoupled from AppKit so the indentation rule
/// can be verified here without instantiating an `STTextView`.
struct AutoIndentTests {

    @Test func previousLineWithFourSpaceIndent() {
        let source = "    let x = 1"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "    ")
    }

    @Test func previousLineWithTabIndent() {
        let source = "\tlet x = 1"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "\t")
    }

    @Test func previousLineEndingInBraceAddsExtraIndent() {
        // 2-space indent, line ends in `{` → 2 spaces + 4 spaces
        let source = "  func foo() {"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "      ")
    }

    @Test func braceAtColumnZeroAddsOneLevel() {
        let source = "{"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "    ")
    }

    @Test func insertionAtStartOfDocumentReturnsEmpty() {
        let indent = AutoIndent.indent(
            source: "hello",
            insertionPointUTF16Offset: 0
        )
        #expect(indent == "")
    }

    @Test func previousLineIsEmptyReturnsEmpty() {
        // Caret on an empty line following a populated line.
        let source = "first\n"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "")
    }

    @Test func multiLineSourceCopiesCurrentLineIndent() {
        // Caret at the end of line 2 — should copy line 2's indent, not line 1's.
        let source = "func outer() {\n    let inner = 1"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "    ")
    }

    @Test func mixedTabsAndSpacesCopiedLiterally() {
        // Mixed leading whitespace — tabs and spaces should be preserved in order.
        let source = "\t  mixed"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "\t  ")
    }

    @Test func caretInsideLeadingWhitespaceCopiesOnlyWhatPrecedes() {
        // Caret sits after two spaces of a four-space indent.
        let source = "    let x = 1"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: 2
        )
        #expect(indent == "  ")
    }

    @Test func braceAfterTabIndentAddsFourSpaces() {
        // Leading tab + brace-terminated line → one tab + 4 spaces.
        let source = "\tif true {"
        let indent = AutoIndent.indent(
            source: source,
            insertionPointUTF16Offset: source.utf16.count
        )
        #expect(indent == "\t    ")
    }
}
