//
//  QuickIconsTests.swift
//  QuickIconsTests
//

import Foundation
import Testing
@testable import QuickIcons

// MARK: - AppIconVariant

struct AppIconVariantTests {
    @Test func variantCount() {
        #expect(AppIconVariant.all.count == 28)
    }

    @Test func allFilenamesNonEmpty() {
        for variant in AppIconVariant.all {
            #expect(!variant.filename.isEmpty)
            #expect(!variant.idiom.isEmpty)
            #expect(!variant.scale.isEmpty)
            #expect(!variant.pointSize.isEmpty)
        }
    }

    @Test func noduplicateFilenames() {
        let filenames = AppIconVariant.all.map(\.filename)
        #expect(Set(filenames).count == filenames.count)
    }

    @Test func allPixelSizesPositive() {
        for variant in AppIconVariant.all {
            #expect(variant.pixelSize > 0)
        }
    }
}

// MARK: - ExportableIcon

struct ExportableIconTests {
    @Test(arguments: ExportableIcon.allCases)
    func titleNonEmpty(icon: ExportableIcon) {
        #expect(!icon.title.isEmpty)
    }

    @Test(arguments: ExportableIcon.allCases)
    func exportDirectoryNameEndsWithAppiconset(icon: ExportableIcon) {
        #expect(icon.exportDirectoryName.hasSuffix(".appiconset"))
    }

    @Test func allCasesHaveUniqueDirectoryNames() {
        let names = ExportableIcon.allCases.map(\.exportDirectoryName)
        #expect(Set(names).count == names.count)
    }
}

// MARK: - IconExportService integration

@MainActor
struct IconExportServiceTests {
    private func makeTempDirectory() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    @Test(arguments: ExportableIcon.allCases)
    func exportCreatesAppiconsetDirectory(icon: ExportableIcon) throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(icon, to: base)

        #expect(result.lastPathComponent == icon.exportDirectoryName)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: result.path, isDirectory: &isDir)
        #expect(exists && isDir.boolValue)
    }

    @Test(arguments: ExportableIcon.allCases)
    func exportWritesAllPNGs(icon: ExportableIcon) throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(icon, to: base)

        for variant in AppIconVariant.all {
            let file = result.appendingPathComponent(variant.filename)
            #expect(FileManager.default.fileExists(atPath: file.path), "\(variant.filename) missing")
        }
    }

    @Test(arguments: ExportableIcon.allCases)
    func exportWritesValidContentsJSON(icon: ExportableIcon) throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let result = try IconExportService().export(icon, to: base)
        let contentsURL = result.appendingPathComponent("Contents.json")

        let data = try Data(contentsOf: contentsURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        let images = json?["images"] as? [[String: Any]]
        #expect(images?.count == AppIconVariant.all.count)
    }

    @Test(arguments: ExportableIcon.allCases)
    func exportOverwritesExistingAppiconset(icon: ExportableIcon) throws {
        let base = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let service = IconExportService()
        _ = try service.export(icon, to: base)

        // Second export should not throw even though the directory already exists.
        #expect(throws: Never.self) {
            _ = try service.export(icon, to: base)
        }
    }
}
