//
//  SlackCLI.swift
//  QuickIcons — example icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`.
//
//  Concept: a Slack-aubergine terminal tile glowing like a spotlight against a
//  deep blue-black ground — Slack from the command line. A `>_` prompt sits
//  below a title bar of Slack-colored dots. Same character as the other icons:
//  a single glowing hero, cast against cool dark.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Deep blue-black ground (shared character with the other icons)
    static let scGroundCore = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let scGroundEdge = Color(red: 0.012, green: 0.018, blue: 0.045)

    // Cool spotlight haze + aubergine halo cast by the tile
    static let scGlowCool = Color(red: 0.42, green: 0.56, blue: 0.95)
    static let scHalo = Color(red: 0.60, green: 0.22, blue: 0.58)

    // Terminal tile — Slack aubergine
    static let scTileTop = Color(red: 0.44, green: 0.17, blue: 0.44)
    static let scTileMid = Color(red: 0.29, green: 0.08, blue: 0.29)
    static let scTileBot = Color(red: 0.17, green: 0.04, blue: 0.19)

    // Slack brand colors
    static let slackBlue   = Color(red: 0.21, green: 0.77, blue: 0.94)
    static let slackGreen  = Color(red: 0.18, green: 0.71, blue: 0.49)
    static let slackYellow = Color(red: 0.93, green: 0.70, blue: 0.18)
    static let slackRed    = Color(red: 0.88, green: 0.12, blue: 0.35)

    // Specular rim
    static let scRimHi = Color(red: 1.0, green: 0.96, blue: 1.0)
    static let scRimLow = Color(red: 0.34, green: 0.12, blue: 0.34)
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Terminal tile geometry
    private var tileW: CGFloat { size * 0.56 }
    private var tileH: CGFloat { size * 0.46 }
    private var tileRadius: CGFloat { tileH * 0.20 }

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

            // Aubergine halo cast by the tile
            RadialGradient(
                gradient: Gradient(colors: [Color.scHalo.opacity(0.55), .clear]),
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: size * 0.42
            )
            .blendMode(.screen)

            hero
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }

    // MARK: Hero terminal tile

    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
        return ZStack {
            // Aubergine surface
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .scTileTop, location: 0.0),
                        .init(color: .scTileMid, location: 0.55),
                        .init(color: .scTileBot, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            terminalContent

            // Glossy top sheen
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.30), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.softLight)

            // Specular rim
            shape.strokeBorder(
                LinearGradient(
                    colors: [.scRimHi, .scRimLow],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: tileW * 0.010
            )

            // Top-leading bright catch
            shape.strokeBorder(
                RadialGradient(
                    gradient: Gradient(colors: [.white.opacity(0.8), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: tileW * 0.4
                ),
                lineWidth: tileW * 0.014
            )
            .blendMode(.screen)
        }
        .frame(width: tileW, height: tileH)
        .shadow(color: .black.opacity(0.45), radius: size * 0.045, y: size * 0.022)
        .shadow(color: Color.scHalo.opacity(0.45), radius: size * 0.07)
    }

    // MARK: Terminal content (title-bar dots + prompt)

    private var dot: CGFloat { size * 0.028 }

    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar dots in Slack colors
            HStack(spacing: dot * 0.85) {
                Circle().fill(Color.slackRed).frame(width: dot, height: dot)
                Circle().fill(Color.slackYellow).frame(width: dot, height: dot)
                Circle().fill(Color.slackGreen).frame(width: dot, height: dot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Prompt: blue chevron + a glowing cursor block, left-aligned
            HStack(alignment: .center, spacing: size * 0.024) {
                Image(systemName: "chevron.right")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(Color.slackBlue)

                RoundedRectangle(cornerRadius: size * 0.012, style: .continuous)
                    .fill(.white)
                    .frame(width: size * 0.045, height: size * 0.115)
                    .shadow(color: .white.opacity(0.6), radius: size * 0.012)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(height: tileH * 0.06)
        }
        .padding(.horizontal, tileW * 0.10)
        .padding(.vertical, tileH * 0.13)
        .frame(width: tileW, height: tileH)
    }
}
