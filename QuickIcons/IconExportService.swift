//
//  IconExportService.swift
//  QuickIcons
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum IconExportError: LocalizedError {
    case renderingFailed(size: CGFloat)
    case pngEncodingFailed(path: String)

    var errorDescription: String? {
        switch self {
        case .renderingFailed(let size):
            "Could not render the icon at \(Int(size)) px."
        case .pngEncodingFailed(let path):
            "Could not write PNG data to \(path)."
        }
    }
}

/// Renders SwiftUI icon views into a complete Apple AppIcon.appiconset bundle on disk.
@MainActor
struct IconExportService {
    /// Exports all icon variants using a view factory closure into a new subdirectory inside `baseURL`.
    /// The factory receives the pixel size for each variant and returns the view to render.
    /// Returns the URL of the created `.appiconset` directory.
    func export(viewFactory: @escaping (CGFloat) -> AnyView, name: String, to baseURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let directoryName = "\(name).appiconset"
        let destination = baseURL.appendingPathComponent(directoryName, isDirectory: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for variant in AppIconVariant.all {
            let view = viewFactory(variant.pixelSize)
            guard let image = render(view, pixelSize: variant.pixelSize) else {
                throw IconExportError.renderingFailed(size: variant.pixelSize)
            }
            try writePNG(image, to: destination.appendingPathComponent(variant.filename))
        }

        let contentsData = try JSONEncoder.appIconEncoder.encode(
            AppIconContents(images: AppIconVariant.all.map {
                .init(filename: $0.filename, idiom: $0.idiom, scale: $0.scale, size: $0.pointSize)
            })
        )
        try contentsData.write(to: destination.appendingPathComponent("Contents.json"), options: .atomic)

        return destination
    }

    private func render<V: View>(_ view: V, pixelSize: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: pixelSize, height: pixelSize)
        return renderer.cgImage
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw IconExportError.pngEncodingFailed(path: url.path)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw IconExportError.pngEncodingFailed(path: url.path)
        }
    }
}

// MARK: - Icon variant catalogue

struct AppIconVariant {
    let filename: String
    let pixelSize: CGFloat
    let idiom: String
    let pointSize: String
    let scale: String

    static let all: [AppIconVariant] = [
        .init(filename: "iphone-20@2x.png",       pixelSize: 40,   idiom: "iphone",        pointSize: "20x20",     scale: "2x"),
        .init(filename: "iphone-20@3x.png",       pixelSize: 60,   idiom: "iphone",        pointSize: "20x20",     scale: "3x"),
        .init(filename: "iphone-29@2x.png",       pixelSize: 58,   idiom: "iphone",        pointSize: "29x29",     scale: "2x"),
        .init(filename: "iphone-29@3x.png",       pixelSize: 87,   idiom: "iphone",        pointSize: "29x29",     scale: "3x"),
        .init(filename: "iphone-40@2x.png",       pixelSize: 80,   idiom: "iphone",        pointSize: "40x40",     scale: "2x"),
        .init(filename: "iphone-40@3x.png",       pixelSize: 120,  idiom: "iphone",        pointSize: "40x40",     scale: "3x"),
        .init(filename: "iphone-60@2x.png",       pixelSize: 120,  idiom: "iphone",        pointSize: "60x60",     scale: "2x"),
        .init(filename: "iphone-60@3x.png",       pixelSize: 180,  idiom: "iphone",        pointSize: "60x60",     scale: "3x"),
        .init(filename: "ipad-20.png",            pixelSize: 20,   idiom: "ipad",          pointSize: "20x20",     scale: "1x"),
        .init(filename: "ipad-20@2x.png",         pixelSize: 40,   idiom: "ipad",          pointSize: "20x20",     scale: "2x"),
        .init(filename: "ipad-29.png",            pixelSize: 29,   idiom: "ipad",          pointSize: "29x29",     scale: "1x"),
        .init(filename: "ipad-29@2x.png",         pixelSize: 58,   idiom: "ipad",          pointSize: "29x29",     scale: "2x"),
        .init(filename: "ipad-40.png",            pixelSize: 40,   idiom: "ipad",          pointSize: "40x40",     scale: "1x"),
        .init(filename: "ipad-40@2x.png",         pixelSize: 80,   idiom: "ipad",          pointSize: "40x40",     scale: "2x"),
        .init(filename: "ipad-76.png",            pixelSize: 76,   idiom: "ipad",          pointSize: "76x76",     scale: "1x"),
        .init(filename: "ipad-76@2x.png",         pixelSize: 152,  idiom: "ipad",          pointSize: "76x76",     scale: "2x"),
        .init(filename: "ipad-83.5@2x.png",       pixelSize: 167,  idiom: "ipad",          pointSize: "83.5x83.5", scale: "2x"),
        .init(filename: "ios-marketing-1024.png", pixelSize: 1024, idiom: "ios-marketing", pointSize: "1024x1024", scale: "1x"),
        .init(filename: "icon_16x16.png",         pixelSize: 16,   idiom: "mac",           pointSize: "16x16",     scale: "1x"),
        .init(filename: "icon_16x16@2x.png",      pixelSize: 32,   idiom: "mac",           pointSize: "16x16",     scale: "2x"),
        .init(filename: "icon_32x32.png",         pixelSize: 32,   idiom: "mac",           pointSize: "32x32",     scale: "1x"),
        .init(filename: "icon_32x32@2x.png",      pixelSize: 64,   idiom: "mac",           pointSize: "32x32",     scale: "2x"),
        .init(filename: "icon_128x128.png",       pixelSize: 128,  idiom: "mac",           pointSize: "128x128",   scale: "1x"),
        .init(filename: "icon_128x128@2x.png",    pixelSize: 256,  idiom: "mac",           pointSize: "128x128",   scale: "2x"),
        .init(filename: "icon_256x256.png",       pixelSize: 256,  idiom: "mac",           pointSize: "256x256",   scale: "1x"),
        .init(filename: "icon_256x256@2x.png",    pixelSize: 512,  idiom: "mac",           pointSize: "256x256",   scale: "2x"),
        .init(filename: "icon_512x512.png",       pixelSize: 512,  idiom: "mac",           pointSize: "512x512",   scale: "1x"),
        .init(filename: "icon_512x512@2x.png",    pixelSize: 1024, idiom: "mac",           pointSize: "512x512",   scale: "2x"),
    ]
}

// MARK: - Contents.json model

private struct AppIconContents: Encodable {
    struct ImageEntry: Encodable {
        let filename: String
        let idiom: String
        let scale: String
        let size: String
    }

    struct Info: Encodable {
        let author = "xcode"
        let version = 1
    }

    let images: [ImageEntry]
    let info = Info()
}

private extension JSONEncoder {
    static let appIconEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
