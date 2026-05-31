//
//  AmazonOrderExport.swift
//  QuickIcons — example icon
//
//  Open this file in QuickIcons to render and export it. The app renders the
//  top-level `IconView`; `ReceiptShape` is a helper it uses.
//
//  Concept: a warm receipt glowing like a spotlight against a deep blue-black
//  ground — order records, lit and ready to export. Same character as the
//  QuickIcons app icon: a single warm hero, cast against cool dark.
//

import SwiftUI

// MARK: - Palette

private extension Color {
    // Deep blue-black ground (shared character with the QuickIcons icon)
    static let azGroundCore = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let azGroundEdge = Color(red: 0.012, green: 0.018, blue: 0.045)

    // Cool spotlight haze
    static let azGlowCool = Color(red: 0.42, green: 0.56, blue: 0.95)

    // Warm halo the receipt casts into the dark
    static let azHalo = Color(red: 1.0, green: 0.55, blue: 0.22)

    // Receipt paper — warm cream → amber → Amazon orange
    static let azPaperTop = Color(red: 1.0, green: 0.95, blue: 0.82)
    static let azPaperMid = Color(red: 1.0, green: 0.82, blue: 0.46)
    static let azPaperBot = Color(red: 1.0, green: 0.60, blue: 0.24)

    // Printed ink (line items)
    static let azInk = Color(red: 0.45, green: 0.22, blue: 0.06)

    // Specular rim
    static let azRimHi = Color(red: 1.0, green: 0.98, blue: 0.90)
    static let azRimLow = Color(red: 0.85, green: 0.40, blue: 0.14)

    // Export badge — a vivid, deeper orange so it reads against the paper
    static let azBadgeHi = Color(red: 1.0, green: 0.56, blue: 0.18)
    static let azBadgeLow = Color(red: 0.90, green: 0.32, blue: 0.06)
}

// MARK: - Receipt shape

/// Tall receipt with softly rounded top corners and a torn (zigzag) bottom edge.
/// Coordinates are normalized to the bounding rect.
struct ReceiptShape: Shape {
    var teeth: Int = 6
    var toothDepth: CGFloat = 0.04   // fraction of height
    var cornerRadius: CGFloat = 0.10 // fraction of width

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = cornerRadius * rect.width
        let tooth = toothDepth * rect.height
        let valley = rect.maxY - tooth

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: valley))

        // Torn bottom: zigzag from right to left
        let toothW = rect.width / CGFloat(teeth)
        var x = rect.maxX
        for i in 0..<teeth {
            x -= toothW
            let y = (i % 2 == 0) ? rect.maxY : valley
            p.addLine(to: CGPoint(x: x, y: y))
        }

        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.closeSubpath()
        return p
    }
}

// MARK: - Icon

struct IconView: View {
    var size: CGFloat

    // Receipt geometry
    private var paperW: CGFloat { size * 0.40 }
    private var paperH: CGFloat { size * 0.54 }

    var body: some View {
        ZStack {
            // Ground: deep blue-black, brighter toward the lit center
            RadialGradient(
                gradient: Gradient(colors: [.azGroundCore, .azGroundEdge]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.85
            )

            // Cool spotlight haze
            RadialGradient(
                gradient: Gradient(colors: [Color.azGlowCool.opacity(0.20), .clear]),
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 0,
                endRadius: size * 0.6
            )
            .blendMode(.screen)

            // Warm halo cast by the receipt
            RadialGradient(
                gradient: Gradient(colors: [Color.azHalo.opacity(0.55), .clear]),
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: size * 0.40
            )
            .blendMode(.screen)

            hero

            exportBadge
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
    }

    // MARK: Export badge

    private var badgeSize: CGFloat { size * 0.22 }

    private var exportBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.azBadgeHi, .azBadgeLow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .strokeBorder(.white.opacity(0.85), lineWidth: badgeSize * 0.05)

            Image(systemName: "arrow.down")
                .font(.system(size: badgeSize * 0.52, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: badgeSize, height: badgeSize)
        .shadow(color: .black.opacity(0.40), radius: size * 0.02, y: size * 0.008)
        .shadow(color: Color.azBadgeLow.opacity(0.5), radius: size * 0.04)
        .offset(x: size * 0.17, y: size * 0.235)
    }

    // MARK: Hero receipt

    private var hero: some View {
        let shape = ReceiptShape()
        return ZStack {
            // Paper
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .azPaperTop, location: 0.0),
                        .init(color: .azPaperMid, location: 0.55),
                        .init(color: .azPaperBot, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Printed line items
            lineItems
                .frame(width: paperW, height: paperH)

            // Glossy top sheen
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.40), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.softLight)

            // Specular rim
            shape.stroke(
                LinearGradient(
                    colors: [.azRimHi, .azRimLow],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: paperW * 0.018
            )

            // Top-leading bright catch
            shape.stroke(
                RadialGradient(
                    gradient: Gradient(colors: [.white.opacity(0.85), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: paperW * 0.55
                ),
                lineWidth: paperW * 0.022
            )
            .blendMode(.screen)
        }
        .frame(width: paperW, height: paperH)
        .rotationEffect(.degrees(-6))
        .shadow(color: .black.opacity(0.45), radius: size * 0.045, y: size * 0.022)
        .shadow(color: Color.azHalo.opacity(0.45), radius: size * 0.07)
    }

    // MARK: Line items

    private var lineItems: some View {
        VStack(alignment: .leading, spacing: paperH * 0.062) {
            itemRow(width: 0.70)
            itemRow(width: 0.58)
            itemRow(width: 0.66)
            itemRow(width: 0.50)

            Spacer().frame(height: paperH * 0.02)

            // "Total" — a bolder, separated line
            bar(widthFraction: 0.44, height: 0.05)
                .opacity(0.9)
        }
        .padding(.horizontal, paperW * 0.16)
        .padding(.top, paperH * 0.16)
        .padding(.bottom, paperH * 0.16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func itemRow(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            bar(widthFraction: width, height: 0.034)
            Spacer(minLength: 0)
            // price tick on the right
            bar(widthFraction: 0.14, height: 0.034)
        }
    }

    private func bar(widthFraction: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.azInk.opacity(0.55))
            .frame(width: paperW * widthFraction, height: paperH * height)
    }
}
