---
dependencies: [11-wire-export-button, 12-future-export-disabled-state]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/26
---

# Preview Pane Polish — Padding & Toast Overlay

## Objective

Polish `PreviewPanel` so the compiled icon has breathing room and the export-success feedback doesn't shove the layout around. Specifically:

1. Double the horizontal padding around the rendered icon compared to today.
2. Change the export success/failure notice from an inline status bar into a floating toast that overlays the preview (doesn't offset layout).

## Acceptance Criteria

- [ ] Preview pane horizontal padding is ~2× the current value (pick one horizontal value and apply it symmetrically).
- [ ] The rendered icon itself stays centered; the extra padding lives outside the image.
- [ ] Export message (success or error) no longer pushes the icon up/down when it appears.
- [ ] Instead it appears as a toast (rounded rectangle, subtle background material / shadow) overlaying the bottom of the preview, with safe horizontal padding from the pane edges.
- [ ] Toast auto-dismisses after a few seconds (success) — errors can stay until the next compile/export attempt OR follow the same timeout; pick whichever feels nicer and explain the choice in the PR.
- [ ] Toast uses a subtle animation on appear/disappear (fade + small slide). No bouncy/overdone transitions.
- [ ] Looks correct in both light and dark mode.
- [ ] Zero-warning build; all tests pass.

## Notes

- Use `ZStack { ... preview content ...; toast overlay aligned to bottom }` or an `.overlay(alignment: .bottom) { ... }` modifier — whichever is cleaner given the existing layout.
- For the toast material, `.regularMaterial` or `.thinMaterial` in a `Capsule`/`RoundedRectangle` reads as native macOS. Use `.shadow(radius: 8, y: 2)` sparingly.
- Transition: `.transition(.move(edge: .bottom).combined(with: .opacity))` inside `withAnimation(.spring(response: 0.35, dampingFraction: 0.9))` (or an equivalent smooth animation).
- Auto-dismiss via a `Task { try? await Task.sleep(for: .seconds(3)); exportMessage = nil }` tied to `.onChange(of: exportMessage)`. Cancel the prior task when a new message replaces the old one.
- Keep the success/error visual distinction (green check vs. orange warning) but subtler than the inline bar.

## Out of Scope

- Restructuring `ExportMessage` or changing the upstream `EditorView` plumbing.
- Animating the compile error state in the preview — only the export toast.
