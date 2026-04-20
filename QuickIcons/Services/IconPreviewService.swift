//
//  IconPreviewService.swift
//  QuickIcons
//

import Foundation
import SwiftUI
import AppKit

/// Loads a compiled dylib produced by `SwiftCompilerService` via ``DylibSession`` and
/// renders its `IconView` to an `NSImage`.
@MainActor
final class IconPreviewService {

    private let session: DylibSession

    init(session: DylibSession) {
        self.session = session
    }

    convenience init() {
        self.init(session: DylibSession())
    }

    /// Renders the icon defined in the dylib at `dylibURL` into an `NSImage` of `size × size` points.
    /// Returns `nil` if loading or rendering fails.
    func render(dylibURL: URL, size: CGFloat) -> NSImage? {
        guard let factory = try? session.loadIcon(at: dylibURL) else {
            return nil
        }

        let view = factory.view(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size, height: size)

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
