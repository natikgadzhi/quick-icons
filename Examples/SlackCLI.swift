//
//  SlackCLI.swift
//  QuickIcons — example icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`.
//
//  Concept: Slack's multicolor hashtag (#channel) glowing like a spotlight
//  against a deep blue-black ground, with a small aubergine key badge for the
//  tool's authentication focus. Same character as the other icons: a single
//  hero, cast against cool dark.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Deep blue-black ground (shared character with the other icons)
    static let scGroundCore = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let scGroundEdge = Color(red: 0.012, green: 0.018, blue: 0.045)

    // Cool spotlight haze + soft white halo so the colors pop
    static let scGlowCool = Color(red: 0.42, green: 0.56, blue: 0.95)

    // Slack brand colors
    static let slackBlue   = Color(red: 0.21, green: 0.77, blue: 0.94)
    static let slackGreen  = Color(red: 0.18, green: 0.71, blue: 0.49)
    static let slackYellow = Color(red: 0.93, green: 0.70, blue: 0.18)
    static let slackRed    = Color(red: 0.88, green: 0.12, blue: 0.35)
    static let slackPlum   = Color(red: 0.29, green: 0.08, blue: 0.29) // aubergine
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Hashtag geometry
    private var barLen: CGFloat { size * 0.42 }
    private var barThick: CGFloat { size * 0.060 }
    private var gap: CGFloat { size * 0.088 }   // offset of each bar from center
    private var slant: Double { -10 }            // italic lean of the vertical strokes

    var body: some View {
        ZStack {
            // Ground: deep blue-black, brighter toward the lit center
            RadialGradient(
                gradient: Gradient(colors: [.scGroundCore, .scGroundEdge]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.85
            )

            // Cool spotlight haze
            RadialGradient(
                gradient: Gradient(colors: [Color.scGlowCool.opacity(0.20), .clear]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.6
            )
            .blendMode(.screen)

            // Soft white halo so the multicolor mark reads against the dark
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.22), .clear]),
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: size * 0.36
            )
            .blendMode(.screen)

            hashtag

            keyBadge
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }

    // MARK: Hashtag

    private var hashtag: some View {
        ZStack {
            // Vertical strokes (slanted), drawn first
            bar(.slackYellow)
                .frame(width: barThick, height: barLen)
                .rotationEffect(.degrees(slant))
                .offset(x: -gap)
            bar(.slackRed)
                .frame(width: barThick, height: barLen)
                .rotationEffect(.degrees(slant))
                .offset(x: gap)

            // Horizontal strokes on top
            bar(.slackBlue)
                .frame(width: barLen, height: barThick)
                .offset(y: -gap)
            bar(.slackGreen)
                .frame(width: barLen, height: barThick)
                .offset(y: gap)
        }
        .frame(width: size * 0.5, height: size * 0.5)
        .shadow(color: .black.opacity(0.35), radius: size * 0.03, y: size * 0.012)
    }

    /// A single rounded stroke of the hashtag: solid color with a soft top gloss.
    private func bar(_ color: Color) -> some View {
        ZStack {
            Capsule().fill(color)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.softLight)
        }
        .shadow(color: color.opacity(0.5), radius: size * 0.018)
    }

    // MARK: Key badge

    private var badgeSize: CGFloat { size * 0.22 }

    private var keyBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.slackPlum.opacity(0.95), Color.slackPlum],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .strokeBorder(.white.opacity(0.85), lineWidth: badgeSize * 0.05)

            Image(systemName: "key.fill")
                .font(.system(size: badgeSize * 0.46, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(45))
        }
        .frame(width: badgeSize, height: badgeSize)
        .shadow(color: .black.opacity(0.40), radius: size * 0.02, y: size * 0.008)
        .shadow(color: Color.slackPlum.opacity(0.6), radius: size * 0.035)
        .offset(x: size * 0.18, y: size * 0.20)
    }
}
