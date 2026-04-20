//
//  UTF16LineOffsetTests.swift
//  QuickIconsTests
//

import Testing
@testable import QuickIcons

/// Tests for `TextOffset.utf16Offset(forLine:in:)`.
///
/// These verify that the line→UTF-16-offset helper returns correct values for
/// ASCII text, text with emoji above the target line (multi-UTF-16-unit scalars),
/// and out-of-range line numbers.
@MainActor
struct UTF16LineOffsetTests {

    @Test func firstLineOffsetIsZero() {
        #expect(TextOffset.utf16Offset(forLine: 1, in: "hello\nworld") == 0)
    }

    @Test func secondLineOffsetAfterASCII() {
        // "hello\n" is 6 UTF-16 code units
        #expect(TextOffset.utf16Offset(forLine: 2, in: "hello\nworld") == 6)
    }

    @Test func emojiAboveTargetLine() {
        // "🎉" is 2 UTF-16 code units; line 1 = "🎉\n" = 3 UTF-16 units
        let source = "🎉\nworld"
        #expect(TextOffset.utf16Offset(forLine: 2, in: source) == 3)
    }

    @Test func multipleEmojisAboveTargetLine() {
        // "👨‍👩‍👧" (family emoji, ZWJ sequence) — 1 grapheme cluster, 8 UTF-16 code units
        // line 1 = "👨‍👩‍👧\n" = 9 UTF-16 units
        let source = "👨\u{200D}👩\u{200D}👧\ncode"
        let familyEmojiUTF16Count = "👨\u{200D}👩\u{200D}👧".utf16.count
        #expect(TextOffset.utf16Offset(forLine: 2, in: source) == familyEmojiUTF16Count + 1)
    }

    @Test func outOfRangeLineReturnsNegativeOne() {
        #expect(TextOffset.utf16Offset(forLine: 5, in: "only\none\nline") == -1)
    }

    @Test func zeroLineReturnsNegativeOne() {
        #expect(TextOffset.utf16Offset(forLine: 0, in: "hello") == -1)
    }

    @Test func singleLineDocumentLine1IsZero() {
        #expect(TextOffset.utf16Offset(forLine: 1, in: "no newlines here") == 0)
    }
}
