//
//  DylibSession.swift
//  QuickIcons
//

import Darwin
import Foundation
import SwiftUI

/// A typed view factory resolved from a compiled user icon dylib.
///
/// `IconFactory` hides the underlying C function pointer and `Unmanaged` bridging so
/// callers can treat it as a plain `(CGFloat) -> AnyView`.
struct IconFactory {
    private let make: (CGFloat) -> AnyView

    fileprivate init(make: @escaping (CGFloat) -> AnyView) {
        self.make = make
    }

    /// Invokes the dylib's `_quickIconsMakeView` bridge to produce an `AnyView` at `size` points.
    func view(size: CGFloat) -> AnyView {
        make(size)
    }
}

/// Errors thrown by ``DylibSession`` when loading or resolving symbols.
enum DylibSessionError: LocalizedError {
    case dlopenFailed(path: String, message: String?)
    case symbolNotFound(symbol: String)

    var errorDescription: String? {
        switch self {
        case .dlopenFailed(let path, let message):
            if let message { return "Could not load dylib at \(path): \(message)" }
            return "Could not load dylib at \(path)."
        case .symbolNotFound(let symbol):
            return "Symbol \(symbol) not found in dylib."
        }
    }
}

/// Owns a single `dlopen` handle for a compiled user icon dylib and exposes
/// a typed ``IconFactory`` resolved from the `_quickIconsMakeView` bridge symbol.
///
/// The session ensures that only one `RTLD_LOCAL` handle is open at a time for the
/// current path — opening a new dylib (or re-opening the same path) closes the prior
/// handle first, which keeps rebuilds from returning stale symbols.
///
/// MainActor-confined: preview + export paths both run on the main actor and the
/// underlying `dlopen`/`dlsym` calls are fast enough to stay there.
@MainActor
final class DylibSession {

    /// Name of the C bridge symbol emitted by `SwiftCompilerService.bridgeSource`.
    static let bridgeSymbol = "_quickIconsMakeView"

    private var handle: UnsafeMutableRawPointer?
    private var loadedPath: String?

    init() {}

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    /// Loads the dylib at `url` (closing any previously held handle) and resolves the
    /// `_quickIconsMakeView` bridge into an ``IconFactory``.
    ///
    /// Calling this method repeatedly is safe: the previous handle is always closed
    /// before a new one is opened, so a freshly-rebuilt dylib at the same path is
    /// always picked up with its latest symbols.
    func loadIcon(at url: URL) throws -> IconFactory {
        closeHandle()

        // RTLD_LOCAL keeps user symbols out of the global namespace so repeated loads
        // of differently-named dylibs don't conflict.
        guard let newHandle = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) }
            throw DylibSessionError.dlopenFailed(path: url.path, message: message)
        }
        handle = newHandle
        loadedPath = url.path

        guard let sym = dlsym(newHandle, Self.bridgeSymbol) else {
            closeHandle()
            throw DylibSessionError.symbolNotFound(symbol: Self.bridgeSymbol)
        }

        // Signature matches `_quickIconsMakeView` in SwiftCompilerService.bridgeSource:
        // the returned pointer is Unmanaged.passRetained(AnyView as AnyObject).toOpaque().
        typealias MakeViewFn = @convention(c) (Double) -> UnsafeMutableRawPointer
        let makeView = unsafeBitCast(sym, to: MakeViewFn.self)

        return IconFactory { size in
            let opaquePtr = makeView(Double(size))
            let obj = Unmanaged<AnyObject>.fromOpaque(opaquePtr).takeRetainedValue()
            return (obj as? AnyView) ?? AnyView(Color.clear.frame(width: size, height: size))
        }
    }

    /// Closes the currently-held dylib handle, if any. Safe to call multiple times.
    func close() {
        closeHandle()
    }

    private func closeHandle() {
        if let handle {
            dlclose(handle)
        }
        handle = nil
        loadedPath = nil
    }
}
