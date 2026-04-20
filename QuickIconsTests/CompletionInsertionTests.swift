import Foundation
import Testing
@testable import QuickIcons

/// Tests the pure `identifierPrefixLength` helper the completion coordinator
/// uses when inserting a completion — it decides how much of the partial word
/// already typed before the caret should be replaced by the completion's
/// plain text.
///
/// Keeping this pure and unit-tested matters because the range math directly
/// drives the `replaceCharacters(in:with:)` call; a bug here corrupts the
/// user's source on every insertion.
@MainActor
struct CompletionInsertionTests {

    /// Identifier characters include ASCII letters, digits, and underscore.
    /// `foo_bar123` is 10 characters and sits at the end of "let foo_bar123",
    /// stopping at the preceding space.
    @Test func countsAsciiIdentifierRun() {
        let source = "let foo_bar123"
        let length = TextOffset.identifierPrefixLength(
            in: source,
            endingAtUTF16Offset: source.utf16.count
        )
        #expect(length == 10)
    }

    /// A non-identifier character (dot, paren, space) terminates the prefix.
    @Test func stopsAtNonIdentifierCharacter() {
        let source = "value.pri"
        let length = TextOffset.identifierPrefixLength(
            in: source,
            endingAtUTF16Offset: source.utf16.count
        )
        #expect(length == 3) // "pri"
    }

    /// Offset of 0 (start of document) yields prefix length 0.
    @Test func zeroOffsetReturnsZero() {
        #expect(
            TextOffset.identifierPrefixLength(
                in: "abc",
                endingAtUTF16Offset: 0
            ) == 0
        )
    }

    /// Offset landing on whitespace/punctuation yields zero length.
    @Test func offsetOnNonIdentifierReturnsZero() {
        let source = "foo "
        #expect(
            TextOffset.identifierPrefixLength(
                in: source,
                endingAtUTF16Offset: source.utf16.count
            ) == 0
        )
    }

    /// Non-ASCII / emoji characters are treated as non-identifier for this
    /// purpose — SourceKit identifiers are effectively ASCII-only in practice
    /// for completion prefixes, and the branch keeps the implementation simple
    /// and fast.
    @Test func nonAsciiTerminatesPrefix() {
        let source = "héllo"
        // 'h' is identifier; 'é' is not; after 'é', "llo" is identifier again.
        // Full length should count only "llo" = 3.
        let length = TextOffset.identifierPrefixLength(
            in: source,
            endingAtUTF16Offset: source.utf16.count
        )
        #expect(length == 3)
    }
}
