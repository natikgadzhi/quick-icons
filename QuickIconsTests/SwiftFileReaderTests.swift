//
//  SwiftFileReaderTests.swift
//  QuickIconsTests
//

import Foundation
import Testing
@testable import QuickIcons

struct SwiftFileReaderTests {

    @Test func readsValidUTF8File() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        let source = "import SwiftUI\n\nstruct Foo: View { var body: some View { EmptyView() } }\n"
        try source.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try readSwiftSource(at: tmp)
        #expect(result == source)
    }

    @Test func throwsReadFailedForMissingFile() {
        let missing = URL(fileURLWithPath: "/tmp/does_not_exist_\(UUID().uuidString).swift")
        #expect(throws: SwiftFileReaderError.self) {
            _ = try readSwiftSource(at: missing)
        }
    }

    @Test func throwsNotUTF8ForBinaryData() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        // Write bytes that are not valid UTF-8 (0xFF 0xFE is a UTF-16 BOM, invalid as UTF-8 sequence)
        let invalidUTF8 = Data([0xFF, 0xFE, 0x00, 0x01])
        try invalidUTF8.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(throws: SwiftFileReaderError.notUTF8) {
            _ = try readSwiftSource(at: tmp)
        }
    }
}
