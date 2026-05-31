//
//  MacIconRimTint.swift
//  QuickIcons
//

import CoreGraphics
import SwiftUI

/// Derives the rim-gloss highlight color for ``MacIconFrame`` by probing the icon artwork.
///
/// The gloss shouldn't be uniformly silvery — it should pick up the icon's own colors near
/// the edge. This renders the artwork to a small bitmap, averages the opaque pixels in a
/// border band, and returns a *light* version of that hue: mostly white with just a smidge
/// of the icon's edge color mixed in. Icons whose edges are transparent fall back to white.
@MainActor
enum MacIconRimTint {
    /// How much of the icon's (lightness-normalized) edge hue to mix into the white gloss.
    private static let tintWeight = 0.22

    /// The gloss highlight color for the artwork produced by `factory`.
    static func highlight(for factory: (CGFloat) -> AnyView, sampleSize: CGFloat = 64) -> Color {
        guard let (r, g, b) = averageBorderColor(for: factory, sampleSize: sampleSize) else {
            return .white
        }
        // Normalize to a pure-hue, fully-light version so the tint reads regardless of how
        // dark the icon is, then keep the result mostly white.
        let peak = max(r, max(g, b))
        guard peak > 0.001 else { return .white }
        let (nr, ng, nb) = (r / peak, g / peak, b / peak)
        return Color(
            red: 1 * (1 - tintWeight) + nr * tintWeight,
            green: 1 * (1 - tintWeight) + ng * tintWeight,
            blue: 1 * (1 - tintWeight) + nb * tintWeight
        )
    }

    /// Average color of the opaque pixels in a band around the artwork's edge, as linear
    /// 0–1 RGB. Returns `nil` if the border has no sufficiently opaque pixels.
    static func averageBorderColor(
        for factory: (CGFloat) -> AnyView,
        sampleSize: CGFloat = 64
    ) -> (r: Double, g: Double, b: Double)? {
        let n = Int(sampleSize)
        guard n > 4 else { return nil }

        let renderer = ImageRenderer(
            content: factory(sampleSize).frame(width: sampleSize, height: sampleSize)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: sampleSize, height: sampleSize)
        guard let cg = renderer.cgImage else { return nil }

        var data = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(
            data: &data,
            width: n,
            height: n,
            bitsPerComponent: 8,
            bytesPerRow: n * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))

        let band = max(2, n / 12)
        var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0.0
        for y in 0..<n {
            for x in 0..<n where x < band || x >= n - band || y < band || y >= n - band {
                let i = (y * n + x) * 4
                // Only count near-opaque pixels; premultiplied values ≈ true color there.
                guard data[i + 3] > 200 else { continue }
                rSum += Double(data[i]) / 255.0
                gSum += Double(data[i + 1]) / 255.0
                bSum += Double(data[i + 2]) / 255.0
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (rSum / count, gSum / count, bSum / count)
    }
}
