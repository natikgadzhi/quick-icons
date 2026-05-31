//
//  IconPreviewServiceTests.swift
//  QuickIconsTests
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import QuickIcons

// MARK: - IconPreviewService Integration Tests

// Serialized because compiles share `tmp/quickicons-usericon.dylib`.
// See the note on SwiftCompilerServiceIntegrationTests.
@MainActor
@Suite(.serialized)
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
        let result = await compiler.compile(source: trivialSource, viewName: "IconView")
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

    /// A full-bleed icon: a solid red square filling the whole canvas, so the corner
    /// pixels reveal whether macOS framing (transparent margin) was applied.
    private let solidSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            Color.red.frame(width: size, height: size)
        }
    }
    """

    /// A solid green icon, used to prove a rebuild renders fresh code rather than the
    /// previously-loaded dylib.
    private let solidGreenSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            Color.green.frame(width: size, height: size)
        }
    }
    """

    /// Reads the RGBA bytes of a single pixel from an `NSImage`'s backing `CGImage`,
    /// sampled at `fraction` of the way along both axes.
    private func pixel(of image: NSImage, fraction: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cg.width, height = cg.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        let p = Int(CGFloat(width) * fraction)
        let i = (p * width + p) * 4
        return (data[i], data[i + 1], data[i + 2], data[i + 3])
    }

    @Test func macOSModeBakesInTransparentMargin() async {
        let result = await compiler.compile(source: solidSource, viewName: "IconView")
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test macOS framing")
            return
        }

        let image = preview.render(dylibURL: dylibURL, size: 256, mode: .macOS)
        let corner = image.flatMap { pixel(of: $0, fraction: 0.02) }
        let center = image.flatMap { pixel(of: $0, fraction: 0.5) }
        #expect(corner?.a == 0, "macOS preview corner must be transparent (the margin)")
        #expect(center?.a == 255, "macOS preview center must be opaque")
    }

    @Test func originalModeStaysFullBleed() async {
        let result = await compiler.compile(source: solidSource, viewName: "IconView")
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test original framing")
            return
        }

        let image = preview.render(dylibURL: dylibURL, size: 256, mode: .original)
        let corner = image.flatMap { pixel(of: $0, fraction: 0.02) }
        #expect(corner?.a == 255, "original preview corner must stay opaque (full-bleed)")
    }

    /// Reproduces the drag-drop bug: compiling a second, different icon must render the
    /// new icon — not the first one's pixels left behind in dyld's image cache.
    @Test func recompiledSourceRendersFreshIconNotStale() async {
        guard case .success(let redURL) = await compiler.compile(source: solidSource, viewName: "IconView") else {
            #expect(Bool(false), "First compile failed")
            return
        }
        let redImage = preview.render(dylibURL: redURL, size: 128, mode: .original)
        let red = redImage.flatMap { pixel(of: $0, fraction: 0.5) }
        #expect(red.map { $0.r > $0.g } == true, "first icon should render red-dominant")

        guard case .success(let greenURL) = await compiler.compile(source: solidGreenSource, viewName: "IconView") else {
            #expect(Bool(false), "Second compile failed")
            return
        }
        let greenImage = preview.render(dylibURL: greenURL, size: 128, mode: .original)
        let green = greenImage.flatMap { pixel(of: $0, fraction: 0.5) }
        #expect(green.map { $0.g > $0.r } == true, "rebuilt icon must render green, not the stale red icon")
    }

    @Test func renderHandlesRepeatedCallsClosingPreviousHandle() async {
        // Compile once and render twice — the service must close the previous handle each time.
        let result = await compiler.compile(source: trivialSource, viewName: "IconView")
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
