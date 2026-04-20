//
//  SDKPathCache.swift
//  QuickIcons
//

import Foundation

/// Process-wide cache for the macOS SDK path resolved via
/// `xcrun --show-sdk-path --sdk macosx`.
///
/// Resolving the SDK path requires spawning `xcrun` and waiting for it to
/// exit. Doing so synchronously at type initialization (previously via a
/// `static let`) blocks whichever thread touches the type first — under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` that's the main thread on the
/// first keystroke in the editor.
///
/// This actor defers resolution to the first async call via `Task.detached`,
/// caches the successful result, and serializes concurrent first-callers so
/// `xcrun` is invoked at most once.
actor SDKPathCache {
    /// Shared cache used by all SourceKit services. A single `xcrun` per
    /// process is the desired behavior; there is no reason to have more than
    /// one instance.
    static let shared = SDKPathCache()

    private var cached: String?

    /// Returns the cached macOS SDK path, resolving it off the caller's
    /// executor on the first invocation. Returns `nil` if `xcrun` fails.
    func path() async -> String? {
        if let cached {
            return cached
        }
        let resolved = await Task.detached { Self.resolveSDKPath() }.value
        if let resolved {
            cached = resolved
        }
        return resolved
    }

    /// Synchronously shells out to `xcrun --show-sdk-path --sdk macosx`.
    /// Marked `nonisolated` so it can be called from a detached task without
    /// hopping back to the actor.
    nonisolated private static func resolveSDKPath() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["--show-sdk-path", "--sdk", "macosx"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        } catch {
            return nil
        }
    }
}
