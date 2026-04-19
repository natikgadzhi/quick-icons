//
//  IconPreviewService.swift
//  QuickIcons
//

import Darwin
import Foundation
import SwiftUI
import AppKit

/// Loads a compiled dylib produced by `SwiftCompilerService`, looks up the
/// `_quickIconsMakeView` C symbol, and renders the returned view to an `NSImage`.
@MainActor
final class IconPreviewService {

    private var handle: UnsafeMutableRawPointer?

    /// Renders the icon defined in the dylib at `dylibURL` into an `NSImage` of `size × size` points.
    /// Returns `nil` if loading or rendering fails.
    func render(dylibURL: URL, size: CGFloat) -> NSImage? {
        // Close the previous handle before opening a new one to avoid symbol conflicts.
        if let existing = handle {
            dlclose(existing)
            handle = nil
        }

        // RTLD_LOCAL keeps user symbols out of the global namespace so repeated
        // loads of differently-named dylibs don't conflict.
        guard let newHandle = dlopen(dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            return nil
        }
        handle = newHandle

        guard let sym = dlsym(newHandle, "_quickIconsMakeView") else {
            return nil
        }

        // Bridge signature matches `_quickIconsMakeView` in SwiftCompilerService.bridgeSource:
        // the returned pointer is Unmanaged.passRetained(AnyView as AnyObject).toOpaque().
        typealias MakeViewFn = @convention(c) (Double) -> UnsafeMutableRawPointer
        let makeView = unsafeBitCast(sym, to: MakeViewFn.self)

        let opaquePtr = makeView(Double(size))
        let obj = Unmanaged<AnyObject>.fromOpaque(opaquePtr).takeRetainedValue()
        guard let view = obj as? AnyView else {
            return nil
        }

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size, height: size)

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
