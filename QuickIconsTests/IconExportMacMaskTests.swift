//
//  IconExportMacMaskTests.swift
//  QuickIconsTests
//
//  Verifies that exported macOS-idiom PNGs receive Apple's app-icon framing:
//  a transparent margin and rounded "squircle" body, baked into the pixels.
//  iOS/iPad variants must stay full-bleed (the OS masks those at display time).
//

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
@testable import QuickIcons

@MainActor
struct IconExportMacMaskTests {
    private func makeTempDirectory() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    /// A solid red square — every pixel inside the artwork is opaque red.
    private func solidColorFactory(_ size: CGFloat) -> AnyView {
        AnyView(Color.red.frame(width: size, height: size))
    }

    /// Reads the RGBA bytes (premultiplied-last, 8 bpc) of a single pixel from a PNG.
    private func pixel(in url: URL, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = image.width, height = image.height
        guard x >= 0, y >= 0, x < width, y < height else { return nil }

        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let i = (y * width + x) * 4
        return (data[i], data[i + 1], data[i + 2], data[i + 3])
    }

    @Test func macIconHasTransparentMarginAndOpaqueCenter() throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(
            viewFactory: solidColorFactory,
            name: "TestIcon",
            to: base
        )

        // icon_512x512@2x.png is a 1024px macOS-idiom variant.
        let macURL = result.appendingPathComponent("icon_512x512@2x.png")

        let corner = try #require(pixel(in: macURL, x: 4, y: 4))
        #expect(corner.a == 0, "macOS icon corner must be transparent (the margin), got alpha \(corner.a)")

        let center = try #require(pixel(in: macURL, x: 512, y: 512))
        #expect(center.a == 255, "macOS icon center must be opaque, got alpha \(center.a)")
        #expect(center.r > center.g && center.r > center.b, "macOS icon center must be red-dominant")
    }

    /// A flat mid-gray square — any per-edge brightness difference comes from the rim
    /// lighting, not the artwork.
    private func solidGrayFactory(_ size: CGFloat) -> AnyView {
        AnyView(Color(white: 0.5).frame(width: size, height: size))
    }

    // MARK: - Rim tint probing

    @Test func borderTintPicksUpDominantHue() {
        let red = MacIconRimTint.averageBorderColor(for: { size in
            AnyView(Color.red.frame(width: size, height: size))
        })
        let redColor = try? #require(red)
        #expect((redColor?.r ?? 0) > (redColor?.g ?? 1), "red artwork → red-dominant border tint")
        #expect((redColor?.r ?? 0) > (redColor?.b ?? 1))

        let blue = MacIconRimTint.averageBorderColor(for: { size in
            AnyView(Color.blue.frame(width: size, height: size))
        })
        let blueColor = try? #require(blue)
        #expect((blueColor?.b ?? 0) > (blueColor?.r ?? 1), "blue artwork → blue-dominant border tint")
    }

    @Test func borderTintIsNilWhenEdgesAreTransparent() {
        // A small circle centered on a transparent canvas leaves the border ring empty.
        let tint = MacIconRimTint.averageBorderColor(for: { size in
            AnyView(Circle().fill(Color.red).frame(width: size * 0.4, height: size * 0.4)
                .frame(width: size, height: size))
        })
        #expect(tint == nil, "transparent border → no tint (falls back to white)")
    }

    @Test func macIconHasGlossyBeveledRimLighting() throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(
            viewFactory: solidGrayFactory,
            name: "TestIcon",
            to: base
        )
        // icon_512x512@2x.png is a 1024px macOS variant; the 824-pt body starts ~100px in.
        let macURL = result.appendingPathComponent("icon_512x512@2x.png")

        func luma(_ x: Int, _ y: Int) throws -> Int {
            let p = try #require(pixel(in: macURL, x: x, y: y))
            return Int(p.r) + Int(p.g) + Int(p.b)
        }

        let center = try luma(512, 512)
        let topEdge = try luma(512, 106)
        let bottomEdge = try luma(512, 918)
        let leftEdge = try luma(106, 512)

        #expect(topEdge > center, "top edge must be brighter than center (specular highlight)")
        #expect(leftEdge > center, "side edge must be brighter than center (all-sides rim)")
        #expect(bottomEdge < center, "bottom edge must be darker than center (glossy inner shadow)")
    }

    @Test func iosVariantStaysFullBleed() throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(
            viewFactory: solidColorFactory,
            name: "TestIcon",
            to: base
        )

        // ios-marketing-1024.png is a 1024px iOS variant — must fill the whole canvas.
        let iosURL = result.appendingPathComponent("ios-marketing-1024.png")

        let corner = try #require(pixel(in: iosURL, x: 4, y: 4))
        #expect(corner.a == 255, "iOS icon corner must stay opaque (full-bleed), got alpha \(corner.a)")
        #expect(corner.r > corner.g && corner.r > corner.b, "iOS icon corner must be red-dominant")
    }
}
