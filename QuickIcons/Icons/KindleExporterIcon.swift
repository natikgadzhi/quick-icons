//
//  KindleExporterIcon.swift
//  QuickIcons
//

import SwiftUI

// MARK: - Palette

private extension Color {
    static let iconBg1 = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let iconBg2 = Color(red: 0.90, green: 0.88, blue: 0.85)

    static let iconBlue = Color(red: 0.24, green: 0.34, blue: 0.6)
    static let iconBlueDeep = Color(red: 0.10, green: 0.16, blue: 0.38)
    static let iconBlueStroke = Color(red: 0.28, green: 0.38, blue: 0.66)
    static let iconBlueStrokeHi = Color(red: 0.55, green: 0.68, blue: 0.92)

    static let iconInk = Color(red: 0.20, green: 0.23, blue: 0.28)
    static let iconStroke = Color(red: 0.32, green: 0.36, blue: 0.42)
    static let iconStrokeHi = Color(red: 0.60, green: 0.64, blue: 0.72)
}

// MARK: - Bookmark shape

struct BookmarkShape: Shape {
    var cornerRadius: CGFloat = 12
    var notchDepth: CGFloat = 0.18

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = cornerRadius
        let notch = rect.height * notchDepth
        let bottom = rect.maxY
        let top = rect.minY

        p.move(to: CGPoint(x: rect.minX + r, y: top))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: top))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: top + r),
            control: CGPoint(x: rect.maxX, y: top)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        p.addLine(to: CGPoint(x: rect.midX, y: bottom - notch))
        p.addLine(to: CGPoint(x: rect.minX, y: bottom))
        p.addLine(to: CGPoint(x: rect.minX, y: top + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: top),
            control: CGPoint(x: rect.minX, y: top)
        )
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

struct KindleExporterIcon: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.iconBg1, .iconBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.6), .clear]),
                center: .topLeading,
                startRadius: 0,
                endRadius: size * 1.0
            )

            Group {
                ZStack {
                    BookmarkShape(cornerRadius: size * 0.04, notchDepth: 0.18)
                        .fill(
                            LinearGradient(
                                colors: [Color.iconBlue, Color.iconBlueDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    BookmarkShape(cornerRadius: size * 0.04, notchDepth: 0.18)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.iconBlueStroke,
                                    Color.iconBlueStrokeHi,
                                    Color.iconBlueStroke,
                                    Color.iconBlueDeep,
                                    Color.iconBlueStroke
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            lineWidth: size * 0.012
                        )

                    BookmarkShape(cornerRadius: size * 0.04, notchDepth: 0.18)
                        .stroke(
                            RadialGradient(
                                colors: [.white.opacity(0.7), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: size * 0.35
                            ),
                            lineWidth: size * 0.014
                        )
                        .blendMode(.screen)
                }
                .frame(width: size * 0.46, height: size * 0.66)
                .shadow(color: .black.opacity(0.16), radius: size * 0.022, y: size * 0.010)
                .shadow(color: .black.opacity(0.10), radius: size * 0.005, y: size * 0.003)

                VStack(alignment: .leading, spacing: size * 0.035) {
                    highlightBar(width: size * 0.28)
                    highlightBar(width: size * 0.32)
                    highlightBar(width: size * 0.24)
                }
                .offset(y: -size * 0.06)
            }
            .offset(y: -size * 0.04)
            .rotationEffect(.degrees(-5))

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.iconInk, Color.iconInk.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.iconStroke,
                                Color.iconStrokeHi,
                                Color.iconStroke,
                                Color.iconInk,
                                Color.iconStroke
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        lineWidth: size * 0.008
                    )

                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .strokeBorder(
                        RadialGradient(
                            colors: [.white.opacity(0.7), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.18
                        ),
                        lineWidth: size * 0.010
                    )
                    .blendMode(.screen)

                Text(".md")
                    .font(.system(size: size * 0.11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.iconBg1)
            }
            .frame(width: size * 0.32, height: size * 0.18)
            .shadow(color: .black.opacity(0.20), radius: size * 0.018, y: size * 0.012)
            .rotationEffect(.degrees(-3))
            .offset(x: size * 0.26, y: size * 0.32)

            FilmGrain(intensity: 0.08, density: Int(size * 6))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }

    @ViewBuilder
    private func highlightBar(width: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.iconBg1.opacity(0.95), Color.iconBg2.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: size * 0.034)
    }
}

#Preview {
    KindleExporterIcon(size: 400)
}
