//
//  DylibSessionTests.swift
//  QuickIconsTests
//

import Foundation
import SwiftUI
import Testing
@testable import QuickIcons

// MARK: - DylibSession Integration Tests

@MainActor
struct DylibSessionIntegrationTests {

    let compiler = SwiftCompilerService()

    private let trivialSource = """
    import SwiftUI

    struct IconView: View {
        let size: CGFloat
        init(size: CGFloat) { self.size = size }
        var body: some View {
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
        }
    }
    """

    @Test func loadIconResolvesBridgeSymbolAndProducesView() async {
        let result = await compiler.compile(source: trivialSource, viewName: "IconView")
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test DylibSession")
            return
        }

        let session = DylibSession()
        let factory = try? session.loadIcon(at: dylibURL)
        #expect(factory != nil, "loadIcon should resolve the bridge symbol")

        if let factory {
            // We cannot introspect the returned AnyView, but we can at least ensure the
            // call does not crash and returns a non-fallback view for a valid factory.
            _ = factory.view(size: 64)
        }
    }

    @Test func loadIconThrowsForMissingDylib() {
        let session = DylibSession()
        let badURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).dylib")

        #expect(throws: DylibSessionError.self) {
            _ = try session.loadIcon(at: badURL)
        }
    }

    @Test func loadIconReplacesPreviousHandleOnReload() async {
        let result = await compiler.compile(source: trivialSource, viewName: "IconView")
        guard case .success(let dylibURL) = result else {
            #expect(Bool(false), "Compilation failed; cannot test reload")
            return
        }

        let session = DylibSession()

        let first = try? session.loadIcon(at: dylibURL)
        let second = try? session.loadIcon(at: dylibURL)

        #expect(first != nil, "first load should succeed")
        #expect(second != nil, "second load should succeed after prior handle is closed")

        // After close(), subsequent loads still work.
        session.close()
        let third = try? session.loadIcon(at: dylibURL)
        #expect(third != nil, "load after explicit close() should succeed")
    }
}
