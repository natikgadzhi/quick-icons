---
dependencies: [10-wire-compile-button]
status: backlog
---

# Wire Export Button to IconExportService

## Objective

Connect the Export button in `EditorView`'s toolbar to export the currently compiled user icon as a full Apple AppIcon.appiconset bundle to a user-selected directory. The export uses the existing `IconExportService` but renders the user's compiled dylib view rather than the hardcoded icon views.

## Acceptance Criteria

- [ ] Tapping "Export" opens an `NSOpenPanel` asking the user to choose an output directory
- [ ] The export renders all 28 icon variants of the user's compiled view using `IconExportService`
- [ ] A success message (the output path) appears below the Export button after export completes
- [ ] An error message appears if the export fails
- [ ] App builds with zero warnings

## Design Notes

`IconExportService.export(_:to:)` currently accepts an `ExportableIcon` enum case. To support the user's compiled view, add a new export path that accepts a SwiftUI `AnyView` factory closure instead:

```swift
// New overload in IconExportService
func export(viewFactory: @escaping (CGFloat) -> AnyView, name: String, to baseURL: URL) throws -> URL
```

This overload is identical to the existing one but calls `viewFactory(variant.pixelSize)` instead of `icon.view(size:)`.

The Export button in `EditorView` calls this with a factory that uses `IconPreviewService`'s loaded symbol (or re-invokes `dlopen` + `_quickIconsMakeView` for each size). The simplest approach: pass `{ size in makeView(Double(size)) }` where `makeView` is looked up once before the export loop.

## Notes

For now, the Export button is always enabled regardless of whether a compile has succeeded — disabling it when there's no compiled icon is tracked separately in task 12. If the user taps Export before compiling, the dylib URL will be nil and the export should show an error message: "Compile the icon first before exporting."
