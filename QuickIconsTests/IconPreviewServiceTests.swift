//
//  IconPreviewServiceTests.swift
//  QuickIconsTests
//

import AppKit
import Foundation
import Testing
@testable import QuickIcons

// MARK: - IconPreviewService Integration Tests

@MainActor
struct IconPreviewServiceIntegrationTests {

    let compiler = SwiftCompilerService()
    let preview = IconPreviewService()

    /// A minimal IconView that satisfies the bridge's expectations.
    /// SwiftCompilerService appends the @_cdecl bridge automatically.
    private let trivialSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            Circle()
                .fill(Color.blue)
                .frame(width: size, height: size)
        }
    }
    """

    @Test func renderReturnNonNilImageForValidDylib() async {
        let result = await compiler.compile(source: trivialSource)
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test render")
            return
        }

        let image = preview.render(dylibURL: dylibURL, size: 128)
        #expect(image != nil, "render should return a non-nil NSImage for a valid dylib")

        if let img = image {
            #expect(img.size.width > 0, "image width should be > 0")
            #expect(img.size.height > 0, "image height should be > 0")
        }
    }

    @Test func renderReturnsNilForMissingDylib() {
        let badURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).dylib")
        let image = preview.render(dylibURL: badURL, size: 128)
        #expect(image == nil, "render should return nil when the dylib file does not exist")
    }

    @Test func renderHandlesRepeatedCallsClosingPreviousHandle() async {
        // Compile once and render twice — the service must close the previous handle each time.
        let result = await compiler.compile(source: trivialSource)
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test repeated render")
            return
        }

        let first = preview.render(dylibURL: dylibURL, size: 64)
        let second = preview.render(dylibURL: dylibURL, size: 128)

        #expect(first != nil, "first render should succeed")
        #expect(second != nil, "second render should succeed")

        if let img = second {
            #expect(img.size.width == 128)
            #expect(img.size.height == 128)
        }
    }
}
