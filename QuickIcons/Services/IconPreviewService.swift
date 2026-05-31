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
    /// `mode` selects whether Apple's macOS framing (rounded body + transparent margin) is applied
    /// or the raw full-bleed artwork is shown. Returns `nil` if loading or rendering fails.
    func render(dylibURL: URL, size: CGFloat, mode: IconPreviewMode = .macOS) -> NSImage? {
        guard let factory = try? session.loadIcon(at: dylibURL) else {
            return nil
        }

        let content: AnyView
        switch mode {
        case .original:
            content = factory.view(size: size)
        case .macOS:
            content = AnyView(MacIconFrame(canvasSize: size) { factory.view(size: $0) })
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size, height: size)

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
