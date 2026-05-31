//
//  CopilotAuthenticator.swift
//  QuickIcons — example icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`; `FilmGrain`/`SeededRNG` are grain-texture helpers.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Navy radial ground
    static let copilotBgCore = Color(red: 0.204, green: 0.251, blue: 0.416)
    static let copilotBgMid  = Color(red: 0.102, green: 0.137, blue: 0.259)
    static let copilotBgEdge = Color(red: 0.039, green: 0.055, blue: 0.118)

    // Shield rim — light source hitting the top edge
    static let copilotRimHi   = Color(red: 0.957, green: 0.969, blue: 1.0)
    static let copilotRimMid  = Color(red: 0.604, green: 0.651, blue: 0.847)
    static let copilotRimLow  = Color(red: 0.224, green: 0.259, blue: 0.416)

    // Cool off-white arrow, matched to the rim highlight
    static let copilotArrow = Color(red: 0.949, green: 0.961, blue: 1.0)
}

// MARK: - Shield shape

/// Rounded heraldic shield, drawn in fractions of the bounding rect.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
        }
        var p = Path()
        p.move(to: pt(0.50, 0.15))
        p.addLine(to: pt(0.79, 0.26))
        p.addLine(to: pt(0.79, 0.52))
        p.addCurve(to: pt(0.50, 0.88), control1: pt(0.79, 0.71), control2: pt(0.655, 0.815))
        p.addCurve(to: pt(0.21, 0.52), control1: pt(0.345, 0.815), control2: pt(0.21, 0.71))
        p.addLine(to: pt(0.21, 0.26))
        p.closeSubpath()
        return p
    }
}

// MARK: - Arrow shape

/// Copilot "send" arrow, traced from the favicon silhouette: a broad dart with a
/// wide left wing, tip at the upper-right, and a subtle concave notch on the lower-left.
/// Coordinates are normalized to the shape's bounding box.
struct CopilotArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
        }
        var p = Path()
        p.move(to: pt(1.0, 0.0))      // tip (upper-right)
        p.addLine(to: pt(0.0, 0.392)) // back-left wing
        p.addLine(to: pt(0.389, 0.595)) // notch
        p.addLine(to: pt(0.625, 1.0)) // keel (bottom)
        p.closeSubpath()
        return p
    }
}

// MARK: - Film grain

struct FilmGrain: View {
    var intensity: Double = 0.1
    var density: Int = 10000

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 42)
            for _ in 0..<density {
                let x = Double(rng.next()) * size.width
                let y = Double(rng.next()) * size.height
                let brightness = Double(rng.next())
                let alpha = (brightness - 0.5) * intensity * 2
                let color: Color = alpha > 0
                    ? .white.opacity(alpha)
                    : .black.opacity(-alpha)
                let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float(state >> 33) / Float(UInt32.max)
    }
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Arrow box: favicon aspect ratio 36:37, sized to sit comfortably in the shield.
    private var arrowWidth: CGFloat { size * 0.42 }
    private var arrowHeight: CGFloat { arrowWidth * 37.0 / 36.0 }

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [.copilotBgCore, .copilotBgMid, .copilotBgEdge]),
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: size * 0.62
            )

            // Shield: faint inner fill + top-rim specular stroke
            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            ShieldShape()
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .copilotRimHi, location: 0.0),
                            .init(color: .copilotRimMid, location: 0.35),
                            .init(color: .copilotRimLow, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.0225
                )

            // Arrow, centered on the shield's visual centroid
            CopilotArrowShape()
                .fill(Color.copilotArrow)
                .frame(width: arrowWidth, height: arrowHeight)
                .offset(x: -size * 0.03, y: -size * 0.01)

            FilmGrain(intensity: 0.07, density: Int(size * 6))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }
}
