//
//  SwiftFileReader.swift
//  QuickIcons
//

import Foundation

/// Errors that can occur when reading a Swift source file.
enum SwiftFileReaderError: LocalizedError, Equatable {
    case notUTF8
    case readFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notUTF8:
            return "The file could not be read as UTF-8 text."
        case .readFailed(let underlying):
            return "Could not read the file: \(underlying.localizedDescription)"
        }
    }

    static func == (lhs: SwiftFileReaderError, rhs: SwiftFileReaderError) -> Bool {
        switch (lhs, rhs) {
        case (.notUTF8, .notUTF8):
            return true
        case (.readFailed, .readFailed):
            return true
        default:
            return false
        }
    }
}

/// Reads the contents of a Swift source file at the given URL as a UTF-8 string.
///
/// - Parameter url: The file URL to read.
/// - Returns: The file contents as a `String`.
/// - Throws: `SwiftFileReaderError.readFailed` if the file cannot be read,
///           `SwiftFileReaderError.notUTF8` if the data is not valid UTF-8.
func readSwiftSource(at url: URL) throws -> String {
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        throw SwiftFileReaderError.readFailed(underlying: error)
    }

    guard let string = String(data: data, encoding: .utf8) else {
        throw SwiftFileReaderError.notUTF8
    }

    return string
}
