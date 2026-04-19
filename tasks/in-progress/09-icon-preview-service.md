---
dependencies: [06-swift-compiler-service]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/11
---

# IconPreviewService

## Objective

Build `IconPreviewService`, a `@MainActor` struct that takes the URL of a compiled dylib (produced by `SwiftCompilerService`), loads it with `dlopen`, looks up the `_quickIconsMakeView` bridge symbol, and renders the icon to an `NSImage` at a given size using `ImageRenderer`.

## Acceptance Criteria

- [ ] `IconPreviewService.render(dylibURL: URL, size: CGFloat) -> NSImage?` exists
- [ ] Returns `nil` if `dlopen` fails, if the symbol is not found, or if rendering fails — never throws
- [ ] Returns a valid `NSImage` for a correctly compiled icon dylib
- [ ] A previously loaded dylib handle is closed (`dlclose`) before opening a new one
- [ ] Unit test: compile a trivial `IconView` via `SwiftCompilerService` in a temp directory, then render it and verify a non-nil image is returned

## Implementation Notes

```swift
import Darwin   // for dlopen, dlsym, dlclose

@MainActor
struct IconPreviewService {
    private var handle: UnsafeMutableRawPointer?

    mutating func render(dylibURL: URL, size: CGFloat) -> NSImage? {
        if let handle { dlclose(handle) }
        handle = dlopen(dylibURL.path, RTLD_NOW | RTLD_LOCAL)
        guard let handle else { return nil }

        typealias MakeViewFn = @convention(c) (Double) -> AnyView
        guard let sym = dlsym(handle, "_quickIconsMakeView") else { return nil }
        let makeView = unsafeBitCast(sym, to: MakeViewFn.self)

        let view = makeView(Double(size))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2   // @2x for crisp preview
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
```

The `unsafeBitCast` from `dlsym` result to a typed function pointer is the standard pattern for calling C symbols from Swift — safe as long as the signature matches the `@_cdecl` bridge injected by `SwiftCompilerService`.

## Notes

- `RTLD_LOCAL` keeps the user's symbols from polluting the global symbol table — important so that two sequential loads don't conflict
- Each load+close cycle means the old `AnyView` from a previous render is invalid after `dlclose` — only use the view within the same `render` call, never store it
- `@2x` scale on the renderer gives a sharper 2× preview image while keeping the logical size at `size` points
