//
//  XcodeBoldCapturesTests.swift
//  QuickIconsTests
//
//  Verifies that the Xcode-style syntax theme bolds the correct
//  tree-sitter-swift captures — keywords and keyword-flavored built-ins,
//  but not types or function names.
//

import Foundation
import Testing
@testable import QuickIcons

struct XcodeBoldCapturesTests {

    // MARK: - Bold captures

    /// The headline acceptance criterion: Swift keywords render in
    /// semibold. `func`, `let`, `var`, `if`, `struct`, `import` and
    /// friends all surface through one of the keyword-flavored
    /// captures below.
    @Test func swiftKeywordCapturesAreBold() {
        let captures = [
            "keyword",            // `func`, `let`, `var`, `struct`, `class`, `enum`, …
            "keyword.function",   // `func`-specific keyword scope in some grammars
            "keyword.return",     // `return`
            "keyword.operator",   // `is`, `as`, `in` used as operators
            "conditional",        // `if`, `else`, `guard`, `switch`, `case`
            "repeat",             // `for`, `while`, `repeat`
            "include",            // `import`
        ]
        for capture in captures {
            #expect(
                XcodeBoldCaptures.isBold(capture),
                "Capture \(capture) should render in semibold"
            )
        }
    }

    /// `self`, `super`, `nil` are tagged `variable.builtin` by the
    /// tree-sitter grammar. Xcode bolds them alongside true keywords;
    /// the theme should match.
    @Test func builtinVariablesAreBold() {
        #expect(XcodeBoldCaptures.isBold("variable.builtin"))
    }

    /// Markdown headings inside doc comments echo the rendered
    /// Markdown hierarchy with a heavier weight.
    @Test func markdownHeadingsAreBold() {
        #expect(XcodeBoldCaptures.isBold("text.title"))
    }

    // MARK: - Regular captures

    /// Types and constructors are colored but not bolded in Xcode —
    /// everything-is-bold reads noisily, so the theme deliberately
    /// leaves these at regular weight.
    @Test func typesAndConstructorsAreRegular() {
        #expect(!XcodeBoldCaptures.isBold("type"))
        #expect(!XcodeBoldCaptures.isBold("constructor"))
    }

    /// Identifiers, function calls, literals, comments, and punctuation
    /// are never bold.
    @Test func regularWeightCaptures() {
        let captures = [
            "plain",
            "variable", "parameter", "property", "label",
            "method", "function.call", "function.macro",
            "boolean", "number", "float",
            "string", "string.regex", "text.literal",
            "comment", "spell",
            "operator",
            "punctuation.bracket", "punctuation.delimiter", "punctuation.special",
        ]
        for capture in captures {
            #expect(
                !XcodeBoldCaptures.isBold(capture),
                "Capture \(capture) should render in regular weight"
            )
        }
    }

    /// Unknown captures fall through to regular weight so a grammar
    /// update that adds a new scope doesn't accidentally bold it.
    @Test func unknownCaptureIsRegular() {
        #expect(!XcodeBoldCaptures.isBold("something.new"))
        #expect(!XcodeBoldCaptures.isBold(""))
    }
}
