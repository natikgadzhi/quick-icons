---
dependencies: [10-wire-compile-button, 11-wire-export-button]
status: backlog
---

# [Future] Keyboard Shortcuts

## Objective

Add keyboard shortcuts for the primary actions in the editor.

## Planned Shortcuts

| Action | Shortcut |
|--------|----------|
| Compile | ⌘R (matches Xcode's "Run") |
| Export | ⌘⇧E |

## Notes

Intentionally deferred. Implement after the core editor loop (tasks 01–11) is stable and the user has had a chance to use the app and confirm the shortcuts feel right.

Use SwiftUI's `.keyboardShortcut` modifier on the toolbar buttons.
