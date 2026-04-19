//
//  IconExportView.swift
//  QuickIcons
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct IconExportView: View {
    @State private var selectedIcon: ExportableIcon = .kindleExporter
    @State private var exportMessage: String?
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("App Icon Export")
                    .font(.title2.weight(.semibold))

                Picker("Icon", selection: $selectedIcon) {
                    ForEach(ExportableIcon.allCases) { icon in
                        Text(icon.title).tag(icon)
                    }
                }
                .pickerStyle(.segmented)
            }

            selectedIcon
                .view(size: 220)
                .padding(20)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 10) {
                Button(isExporting ? "Exporting…" : "Export AppIcon Set") {
                    Task { @MainActor in
                        await exportSelectedIcon()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)

                Text(selectedIcon.exportDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }

    @MainActor
    private func exportSelectedIcon() async {
        guard !isExporting else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let destination = try exportIconSet(for: selectedIcon)
            exportMessage = "Exported \(selectedIcon.title) to \(destination.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

enum ExportableIcon: String, CaseIterable, Identifiable {
    case kindleExporter
    case scrapesBook

    var id: Self { self }

    var title: String {
        switch self {
        case .kindleExporter: "KindleExporter"
        case .scrapesBook: "Scrapes"
        }
    }

    var exportDirectoryName: String {
        switch self {
        case .kindleExporter: "KindleExporter-AppIcon.appiconset"
        case .scrapesBook: "Scrapes-AppIcon.appiconset"
        }
    }

    var exportDescription: String {
        "Exports a full Apple AppIcon set for iPhone, iPad, macOS, and App Store Connect."
    }

    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .kindleExporter: KindleExporterIcon(size: size)
        case .scrapesBook: ScrapesBookIconView(size: size)
        }
    }
}

// MARK: - Export logic

struct AppIconVariant {
    let filename: String
    let pixelSize: CGFloat
    let idiom: String
    let pointSize: String
    let scale: String

    static let allAppleAppIcons: [AppIconVariant] = [
        .init(filename: "iphone-20@2x.png", pixelSize: 40, idiom: "iphone", pointSize: "20x20", scale: "2x"),
        .init(filename: "iphone-20@3x.png", pixelSize: 60, idiom: "iphone", pointSize: "20x20", scale: "3x"),
        .init(filename: "iphone-29@2x.png", pixelSize: 58, idiom: "iphone", pointSize: "29x29", scale: "2x"),
        .init(filename: "iphone-29@3x.png", pixelSize: 87, idiom: "iphone", pointSize: "29x29", scale: "3x"),
        .init(filename: "iphone-40@2x.png", pixelSize: 80, idiom: "iphone", pointSize: "40x40", scale: "2x"),
        .init(filename: "iphone-40@3x.png", pixelSize: 120, idiom: "iphone", pointSize: "40x40", scale: "3x"),
        .init(filename: "iphone-60@2x.png", pixelSize: 120, idiom: "iphone", pointSize: "60x60", scale: "2x"),
        .init(filename: "iphone-60@3x.png", pixelSize: 180, idiom: "iphone", pointSize: "60x60", scale: "3x"),
        .init(filename: "ipad-20.png", pixelSize: 20, idiom: "ipad", pointSize: "20x20", scale: "1x"),
        .init(filename: "ipad-20@2x.png", pixelSize: 40, idiom: "ipad", pointSize: "20x20", scale: "2x"),
        .init(filename: "ipad-29.png", pixelSize: 29, idiom: "ipad", pointSize: "29x29", scale: "1x"),
        .init(filename: "ipad-29@2x.png", pixelSize: 58, idiom: "ipad", pointSize: "29x29", scale: "2x"),
        .init(filename: "ipad-40.png", pixelSize: 40, idiom: "ipad", pointSize: "40x40", scale: "1x"),
        .init(filename: "ipad-40@2x.png", pixelSize: 80, idiom: "ipad", pointSize: "40x40", scale: "2x"),
        .init(filename: "ipad-76.png", pixelSize: 76, idiom: "ipad", pointSize: "76x76", scale: "1x"),
        .init(filename: "ipad-76@2x.png", pixelSize: 152, idiom: "ipad", pointSize: "76x76", scale: "2x"),
        .init(filename: "ipad-83.5@2x.png", pixelSize: 167, idiom: "ipad", pointSize: "83.5x83.5", scale: "2x"),
        .init(filename: "ios-marketing-1024.png", pixelSize: 1024, idiom: "ios-marketing", pointSize: "1024x1024", scale: "1x"),
        .init(filename: "icon_16x16.png", pixelSize: 16, idiom: "mac", pointSize: "16x16", scale: "1x"),
        .init(filename: "icon_16x16@2x.png", pixelSize: 32, idiom: "mac", pointSize: "16x16", scale: "2x"),
        .init(filename: "icon_32x32.png", pixelSize: 32, idiom: "mac", pointSize: "32x32", scale: "1x"),
        .init(filename: "icon_32x32@2x.png", pixelSize: 64, idiom: "mac", pointSize: "32x32", scale: "2x"),
        .init(filename: "icon_128x128.png", pixelSize: 128, idiom: "mac", pointSize: "128x128", scale: "1x"),
        .init(filename: "icon_128x128@2x.png", pixelSize: 256, idiom: "mac", pointSize: "128x128", scale: "2x"),
        .init(filename: "icon_256x256.png", pixelSize: 256, idiom: "mac", pointSize: "256x256", scale: "1x"),
        .init(filename: "icon_256x256@2x.png", pixelSize: 512, idiom: "mac", pointSize: "256x256", scale: "2x"),
        .init(filename: "icon_512x512.png", pixelSize: 512, idiom: "mac", pointSize: "512x512", scale: "1x"),
        .init(filename: "icon_512x512@2x.png", pixelSize: 1024, idiom: "mac", pointSize: "512x512", scale: "2x"),
    ]
}

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

enum IconExportError: LocalizedError {
    case missingPicturesDirectory
    case renderingFailed(size: CGFloat)
    case pngEncodingFailed(path: String)

    var errorDescription: String? {
        switch self {
        case .missingPicturesDirectory:
            "Could not find the Pictures directory."
        case .renderingFailed(let size):
            "Could not render the icon at \(Int(size)) px."
        case .pngEncodingFailed(let path):
            "Could not write PNG data to \(path)."
        }
    }
}

@MainActor
func exportIconSet(for icon: ExportableIcon) throws -> URL {
    let destinationDirectory = try makeExportDirectory(named: icon.exportDirectoryName)

    for variant in AppIconVariant.allAppleAppIcons {
        guard let image = snapshot(of: icon.view(size: variant.pixelSize), pixelSize: variant.pixelSize) else {
            throw IconExportError.renderingFailed(size: variant.pixelSize)
        }

        let imageURL = destinationDirectory.appendingPathComponent(variant.filename)
        try writePNG(image, to: imageURL)
    }

    let contents = AppIconContents(
        images: AppIconVariant.allAppleAppIcons.map {
            .init(filename: $0.filename, idiom: $0.idiom, scale: $0.scale, size: $0.pointSize)
        }
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let contentsURL = destinationDirectory.appendingPathComponent("Contents.json")
    let contentsData = try encoder.encode(contents)
    try contentsData.write(to: contentsURL, options: .atomic)

    return destinationDirectory
}

private func makeExportDirectory(named directoryName: String) throws -> URL {
    let fileManager = FileManager.default

    guard let picturesDirectory = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first else {
        throw IconExportError.missingPicturesDirectory
    }

    let exportsRoot = picturesDirectory.appendingPathComponent("AppIconExports", isDirectory: true)
    let destinationDirectory = exportsRoot.appendingPathComponent(directoryName, isDirectory: true)

    try fileManager.createDirectory(at: exportsRoot, withIntermediateDirectories: true)

    if fileManager.fileExists(atPath: destinationDirectory.path) {
        try fileManager.removeItem(at: destinationDirectory)
    }

    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    return destinationDirectory
}

@MainActor
private func snapshot<V: View>(of target: V, pixelSize: CGFloat) -> CGImage? {
    let renderer = ImageRenderer(content: target)
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(width: pixelSize, height: pixelSize)
    return renderer.cgImage
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IconExportError.pngEncodingFailed(path: url.path)
    }

    CGImageDestinationAddImage(destination, image, nil)

    guard CGImageDestinationFinalize(destination) else {
        throw IconExportError.pngEncodingFailed(path: url.path)
    }
}

#Preview {
    IconExportView()
}
