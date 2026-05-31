//
//  CopilotAuthenticator.swift
//  QuickIcons — example icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`; `ShackleShape` and `KeyStemShape` are helpers it uses.
//
//  Concept: a large cool-steel padlock glowing like a spotlight against a deep
//  blue-black ground — authentication, lit and front-and-center. Same character
//  as the QuickIcons and Amazon icons: a single hero, cast against cool dark.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Deep blue-black ground (shared character with the other icons)
    static let lkGroundCore = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let lkGroundEdge = Color(red: 0.012, green: 0.018, blue: 0.045)

    // Cool spotlight haze + halo cast by the steel lock
    static let lkGlowCool = Color(red: 0.42, green: 0.56, blue: 0.95)
    static let lkHalo = Color(red: 0.40, green: 0.62, blue: 1.0)

    // Lock body — cool steel/blue
    static let lkBodyTop = Color(red: 0.80, green: 0.87, blue: 0.97)
    static let lkBodyMid = Color(red: 0.44, green: 0.58, blue: 0.84)
    static let lkBodyBot = Color(red: 0.20, green: 0.30, blue: 0.60)

    // Shackle — brighter brushed steel
    static let lkShackleHi = Color(red: 0.92, green: 0.95, blue: 1.0)
    static let lkShackleMid = Color(red: 0.58, green: 0.66, blue: 0.80)
    static let lkShackleLow = Color(red: 0.28, green: 0.35, blue: 0.50)

    // Keyhole ink
    static let lkKeyhole = Color(red: 0.09, green: 0.13, blue: 0.28)

    // Specular rim
    static let lkRimHi = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let lkRimLow = Color(red: 0.20, green: 0.28, blue: 0.50)
}

// MARK: - Shackle shape

/// Centerline of a padlock shackle (an "n" — two legs joined by a semicircle).
/// Stroke it with a round line cap to get the metal loop.
struct ShackleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        let archCenterY = rect.minY + r
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: archCenterY))
        p.addArc(
            center: CGPoint(x: rect.midX, y: archCenterY),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Keyhole stem

/// Trapezoid (wider at the bottom) that sits under the keyhole circle.
struct KeyStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topInset = rect.width * 0.30
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Lock geometry
    private var bodyW: CGFloat { size * 0.46 }
    private var bodyH: CGFloat { size * 0.38 }
    private var bodyRadius: CGFloat { bodyW * 0.24 }
    private var shackleSpan: CGFloat { size * 0.24 }
    private var shackleThickness: CGFloat { size * 0.062 }

    var body: some View {
        ZStack {
            // Ground: deep blue-black, brighter toward the lit center
            RadialGradient(
                gradient: Gradient(colors: [.lkGroundCore, .lkGroundEdge]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.85
            )

            // Cool spotlight haze
            RadialGradient(
                gradient: Gradient(colors: [Color.lkGlowCool.opacity(0.22), .clear]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.6
            )
            .blendMode(.screen)

            // Cool halo cast by the lock
            RadialGradient(
                gradient: Gradient(colors: [Color.lkHalo.opacity(0.45), .clear]),
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: size * 0.42
            )
            .blendMode(.screen)

            lock
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }

    // MARK: Lock

    private var lock: some View {
        ZStack {
            shackle
                .offset(y: -size * 0.135)

            lockBody
                .offset(y: size * 0.085)
        }
        .shadow(color: .black.opacity(0.45), radius: size * 0.045, y: size * 0.022)
        .shadow(color: Color.lkHalo.opacity(0.40), radius: size * 0.07)
    }

    private var shackle: some View {
        ShackleShape()
            .stroke(
                LinearGradient(
                    colors: [.lkShackleHi, .lkShackleMid, .lkShackleLow],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: shackleThickness, lineCap: .round, lineJoin: .round)
            )
            .overlay(
                ShackleShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        style: StrokeStyle(lineWidth: shackleThickness * 0.22, lineCap: .round)
                    )
                    .blendMode(.screen)
            )
            .frame(width: shackleSpan, height: size * 0.30)
    }

    private var lockBody: some View {
        let shape = RoundedRectangle(cornerRadius: bodyRadius, style: .continuous)
        return ZStack {
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .lkBodyTop, location: 0.0),
                        .init(color: .lkBodyMid, location: 0.55),
                        .init(color: .lkBodyBot, location: 1.0)
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

            keyhole

            // Specular rim
            shape.strokeBorder(
                LinearGradient(
                    colors: [.lkRimHi, .lkRimLow],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: bodyW * 0.012
            )

            // Top-leading bright catch
            shape.strokeBorder(
                RadialGradient(
                    gradient: Gradient(colors: [.white.opacity(0.85), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: bodyW * 0.4
                ),
                lineWidth: bodyW * 0.016
            )
            .blendMode(.screen)
        }
        .frame(width: bodyW, height: bodyH)
    }

    private var keyhole: some View {
        let circle = bodyW * 0.155
        let stemH = bodyH * 0.26
        return VStack(spacing: -circle * 0.18) {
            Circle()
                .fill(Color.lkKeyhole)
                .frame(width: circle, height: circle)
            KeyStemShape()
                .fill(Color.lkKeyhole)
                .frame(width: circle * 0.9, height: stemH)
        }
        .offset(y: -bodyH * 0.02)
    }
}
