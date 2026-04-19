//
//  IconPreviewService.swift
//  QuickIcons
//

import Darwin
import Foundation
import SwiftUI
import AppKit

// MARK: - IconPreviewService

/// Loads a compiled dylib produced by `SwiftCompilerService`, looks up the
/// `_quickIconsMakeView` C symbol, and renders the returned view to an `NSImage`.
///
/// Deviation from task spec: implemented as `@MainActor final class` rather than `struct`
/// so that the previously-opened dylib handle can be stored as a mutable property without
/// requiring callers to hold a `var` binding. The semantics are identical — both are
/// `@MainActor`-isolated and single-owner — but the class form avoids the `mutating` call
/// requirement and works naturally as a `@StateObject` or injected dependency.
@MainActor
final class IconPreviewService {

    // The handle returned by `dlopen` for the most recently loaded dylib.
    private var handle: UnsafeMutableRawPointer?

    // MARK: - Public API

    /// Renders the icon defined in the dylib at `dylibURL` into an `NSImage` of `size × size` points.
    ///
    /// - Parameters:
    ///   - dylibURL: URL to the `.dylib` produced by `SwiftCompilerService`.
    ///   - size: Logical size (points) of the square image to produce.
    /// - Returns: A rendered `NSImage`, or `nil` if loading or rendering fails for any reason.
    func render(dylibURL: URL, size: CGFloat) -> NSImage? {
        // Close the previous handle before opening a new one to avoid symbol conflicts.
        if let existing = handle {
            dlclose(existing)
            handle = nil
        }

        // Load the dylib. RTLD_LOCAL keeps user symbols out of the global namespace so
        // that repeated loads of differently-named dylibs don't conflict.
        guard let newHandle = dlopen(dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            return nil
        }
        handle = newHandle

        // Look up the C bridge symbol.
        guard let sym = dlsym(newHandle, "_quickIconsMakeView") else {
            return nil
        }

        // The bridge signature is:
        //   @_cdecl("_quickIconsMakeView")
        //   public func _quickIconsMakeView(_ size: Double) -> UnsafeMutableRawPointer
        // where the pointer is Unmanaged.passRetained(AnyView as AnyObject).toOpaque().
        typealias MakeViewFn = @convention(c) (Double) -> UnsafeMutableRawPointer
        let makeView = unsafeBitCast(sym, to: MakeViewFn.self)

        let opaquePtr = makeView(Double(size))

        // Reclaim the retained AnyObject and cast back to AnyView.
        let obj = Unmanaged<AnyObject>.fromOpaque(opaquePtr).takeRetainedValue()
        guard let view = obj as? AnyView else {
            return nil
        }

        // Render to a CGImage using ImageRenderer at @2x for a crisp preview.
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size, height: size)

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
