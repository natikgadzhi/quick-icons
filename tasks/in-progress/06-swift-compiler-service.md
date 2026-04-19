---
dependencies: [03-disable-sandbox-entitlements]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/6
---

# SwiftCompilerService

## Objective

Build `SwiftCompilerService`, a `@MainActor` struct that takes Swift source code as a string, compiles it to a dynamic library using a `swiftc` subprocess, and returns either the URL of the compiled dylib or a list of structured diagnostics. This is the core compilation engine for the live editor.

## Acceptance Criteria

- [ ] `SwiftCompilerService.compile(source:) async throws -> CompilationResult` exists
- [ ] `CompilationResult` is either `.success(dylibURL: URL)` or `.failure(diagnostics: [SwiftDiagnostic])`
- [ ] `SwiftDiagnostic` has `line: Int`, `column: Int`, `severity: Severity` (`error`/`warning`/`note`), `message: String`
- [ ] The service injects a known bridge function around the user's source (see Notes)
- [ ] stderr is parsed line-by-line with regex: `^.*:(\d+):(\d+): (error|warning|note): (.+)$`
- [ ] The compiled dylib is written to a temp directory (e.g. `FileManager.default.temporaryDirectory`)
- [ ] A previous dylib at the same temp path is removed before recompiling
- [ ] Unit tests cover: successful compilation of a trivial SwiftUI view, parse of a multi-diagnostic stderr string, compile failure returns diagnostics not a thrown error
- [ ] `xcodebuild test` passes

## Bridge Injection

The user's source is expected to define a SwiftUI `View` named `IconView` with an `init(size: CGFloat)`. The service appends this bridge to the end of the user's source before compiling:

```swift
import SwiftUI
@_cdecl("_quickIconsMakeView")
public func _quickIconsMakeView(_ size: Double) -> AnyView {
    AnyView(IconView(size: CGFloat(size)))
}
```

The compiled dylib exposes `_quickIconsMakeView` as a C symbol, which `IconPreviewService` (task 09) will look up via `dlsym`.

## Compilation Invocation

```swift
let args: [String] = [
    "/usr/bin/swiftc",
    "-emit-library",
    "-o", dylibPath,
    "-module-name", "UserIcon",
    sourceFilePath,
    // SDK and framework search paths derived from active Xcode toolchain
    "-sdk", sdkPath,   // xcrun --sdk macosx --show-sdk-path
    "-target", "arm64-apple-macosx15.0",  // or detect at runtime
]
```

Use `Process` to run `swiftc`. Capture stdout and stderr separately. The dylib is only valid if the process exits with code 0.

Detect `sdkPath` at init time via `xcrun --sdk macosx --show-sdk-path` (one-time cached call) so it doesn't block each compile.

## Notes

- This service is tested without the UI — unit tests can invoke `compile(source:)` directly with a simple SwiftUI view string
- Do not hardcode the SDK path — derive it from `xcrun` at runtime
- If `swiftc` is not found at `/usr/bin/swiftc`, check `/usr/bin/env swiftc` or derive from `xcrun -f swiftc`
- The temp dylib path should be stable per-session (e.g. `tmp/quickicons-usericon.dylib`) so repeated compiles overwrite rather than accumulate
