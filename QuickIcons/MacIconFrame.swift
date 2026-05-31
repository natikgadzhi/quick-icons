//
//  MacIconFrame.swift
//  QuickIcons
//

import SwiftUI

/// Apple's macOS app-icon grid proportions.
///
/// macOS displays app-icon PNGs verbatim — unlike iOS, which masks icons to the rounded
/// shape at display time — so the "squircle" body and the surrounding transparent margin
/// must be baked into the pixels. These ratios match Apple's reference grid: a rounded
/// content body of 824 pt on a 1024-pt canvas, with a 185.4-pt continuous corner radius.
enum MacIconGeometry {
    /// The content body's fraction of the full canvas; the remainder is a transparent margin.
    static let bodyRatio: CGFloat = 824.0 / 1024.0
    /// Continuous corner radius as a fraction of the content body's size.
    static let cornerRadiusRatio: CGFloat = 185.4 / 824.0

    /// The content body size, in points, for a given full canvas size.
    static func bodySize(forCanvas canvasSize: CGFloat) -> CGFloat { canvasSize * bodyRatio }
}

/// Wraps icon artwork in Apple's macOS app-icon framing: the artwork is inset to the
/// standard content body, clipped to the continuous rounded rectangle, and centered on a
/// transparent canvas of `canvasSize`. The artwork is built at the body size so it scales
/// to fill the rounded body rather than the full canvas.
struct MacIconFrame<Content: View>: View {
    /// The full canvas size, in points. The artwork is inset within this.
    let canvasSize: CGFloat
    /// Builds the artwork at the body size passed in.
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        let bodySize = MacIconGeometry.bodySize(forCanvas: canvasSize)
        content(bodySize)
            .frame(width: bodySize, height: bodySize)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: bodySize * MacIconGeometry.cornerRadiusRatio,
                    style: .continuous
                )
            )
            .frame(width: canvasSize, height: canvasSize)
    }
}
