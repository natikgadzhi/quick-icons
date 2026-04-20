import Foundation

/// Shared build/environment constants used by the Swift toolchain services
/// (diagnostics, completion, and in-process compilation).
///
/// Centralising the target triple here avoids drift between services that all
/// need to invoke `swiftc`/SourceKit with the same `-target` value.
enum BuildEnvironment {

    /// The Swift `-target` triple used for user-icon compilation and
    /// SourceKit requests.
    ///
    /// The architecture is derived at runtime from the current process, and
    /// the macOS deployment version is computed from
    /// `ProcessInfo.operatingSystemVersion`. SourceKit and `swiftc` only need
    /// a reasonable floor version here — matching the host OS keeps us in
    /// sync with the toolchain selected by `xcode-select` / `xcrun`.
    static let targetTriple: String = {
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = "arm64"
        #endif

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(version.majorVersion).\(version.minorVersion)"
        return "\(arch)-apple-macosx\(osVersion)"
    }()
}
