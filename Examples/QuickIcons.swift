//
//  QuickIcons.swift
//  QuickIcons — the app's own icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`.
//
//  Concept: a single glowing app-icon squircle, lit like a spotlight against a
//  deep blue-black ground — the warm "icon being made" is itself the light
//  source. Minimal, in the spirit of the Scrapes example's spotlight-on-dark.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Deep blue-black ground (cool, near-black with a navy bias)
    static let qiGroundCore = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let qiGroundEdge = Color(red: 0.012, green: 0.018, blue: 0.045)

    // Cool spotlight haze filling the dark
    static let qiGlowCool = Color(red: 0.42, green: 0.56, blue: 0.95)

    // Warm halo the hero squircle casts into the dark
    static let qiHalo = Color(red: 1.0, green: 0.50, blue: 0.28)

    // Hero squircle — warm gold → coral → pink
    static let qiTileTop = Color(red: 1.0, green: 0.82, blue: 0.38)
    static let qiTileMid = Color(red: 1.0, green: 0.55, blue: 0.30)
    static let qiTileBot = Color(red: 0.95, green: 0.30, blue: 0.44)

    // Specular rim
    static let qiRimHi = Color(red: 1.0, green: 0.96, blue: 0.88)
    static let qiRimLow = Color(red: 0.78, green: 0.26, blue: 0.30)
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Hero squircle geometry
    private var tile: CGFloat { size * 0.50 }
    private var tileRadius: CGFloat { tile * 0.2237 } // Apple superellipse-ish ratio

    var body: some View {
        ZStack {
            // Ground: deep blue-black, brighter toward the lit center
            RadialGradient(
                gradient: Gradient(colors: [.qiGroundCore, .qiGroundEdge]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.85
            )

            // Cool spotlight haze
            RadialGradient(
                gradient: Gradient(colors: [Color.qiGlowCool.opacity(0.22), .clear]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.6
            )
            .blendMode(.screen)

            // Warm halo cast by the hero
            RadialGradient(
                gradient: Gradient(colors: [Color.qiHalo.opacity(0.55), .clear]),
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

    // MARK: Hero squircle

    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
        return ZStack {
            // Base warm gradient
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .qiTileTop, location: 0.0),
                        .init(color: .qiTileMid, location: 0.55),
                        .init(color: .qiTileBot, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Glossy top sheen
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.softLight)

            // Diagonal glass sweep across the upper face
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: 0.0),
                        .init(color: .white.opacity(0.40), location: 0.30),
                        .init(color: .white.opacity(0.08), location: 0.50),
                        .init(color: .clear, location: 0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)

            // Specular rim
            shape.strokeBorder(
                LinearGradient(
                    colors: [.qiRimHi, .qiRimLow],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: tile * 0.016
            )

            // Top-leading bright catch
            shape.strokeBorder(
                RadialGradient(
                    gradient: Gradient(colors: [.white.opacity(0.85), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: tile * 0.45
                ),
                lineWidth: tile * 0.02
            )
            .blendMode(.screen)
        }
        .frame(width: tile, height: tile)
        .rotationEffect(.degrees(-10))
        .shadow(color: .black.opacity(0.45), radius: size * 0.045, y: size * 0.022)
        .shadow(color: Color.qiHalo.opacity(0.45), radius: size * 0.07)
    }
}
