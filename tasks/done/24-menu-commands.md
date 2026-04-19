---
dependencies: [18-open-swift-file]
status: in-progress
pr: https://github.com/natikgadzhi/quick-icons/pull/34
---

# Wire Build and Export to File Menu (with Icons)

## Objective

Expose the two primary editor actions as menu items under **File**, matching how `File → Open…` was added in task 18. Both items should also carry their SF Symbol icons (same symbols as the toolbar buttons) so the menu reads consistently with the toolbar.

| Menu item | Shortcut | SF Symbol | Current toolbar label |
|-----------|----------|-----------|------------------------|
| File → Build | ⌘B (tentative — confirm no system conflict) | `hammer.fill` | "Build" |
| File → Export | ⌘⇧E (tentative) | `square.and.arrow.up` | "Export" |

## Acceptance Criteria

- [ ] "Build" item appears in the File menu (after Open…) and triggers the same action as the toolbar Build button.
- [ ] "Export" item appears in the File menu and triggers the same action as the toolbar Export button.
- [ ] Both items show their SF Symbol icons in the menu (use `Label("Build", systemImage: "hammer.fill")` inside the `Button` — `CommandGroup`/`CommandMenu` items render the image in the menu on macOS 14+).
- [ ] Export menu item is disabled when `hasCompiledIcon == false` (same rule as the toolbar Export button — see task 12).
- [ ] Build item is always enabled.
- [ ] Keyboard shortcuts bound via `.keyboardShortcut(...)`. Verify ⌘B does not collide with any standard macOS text-editing shortcut in the editor (if it does, pick a different letter and document).
- [ ] The underlying action functions (currently `compile()` and `export()` in `EditorView`) are reused — do not duplicate the logic.
- [ ] Zero-warning build; tests pass.

## Notes

- Task 18 demonstrated the wiring pattern: the command posts a `Notification` and `EditorView` observes via `.onReceive`. Use the same approach here — add two new `Notification.Name`s (e.g., `.buildRequested`, `.exportRequested`) and observe them in `EditorView`. Keep the naming consistent with task 18's `.openSwiftFileNotification`.
- Naming: we renamed the toolbar label to "Build" in task 10, but the underlying function in `EditorView` is still called `compile()`. This task is only about the user-facing menu label — **do not rename the `compile()` function** (a rename deserves its own focused PR). The user message that prompted this task noted "right now we call it compile" to clarify the target naming is "Build" at the menu level.
- The Export disabled-state wiring needs the command to read `hasCompiledIcon`. Since `EditorView` owns that state, either:
  - Lift `hasCompiledIcon` into a shared `@Observable` editor state that both the command and the view read (more plumbing but cleaner), OR
  - Have the command always post the notification, and let `EditorView`'s `.onReceive` handler no-op if `hasCompiledIcon == false` (simpler, but the menu item won't *appear* disabled — it'll just silently do nothing). **Not acceptable** — menu items must reflect disabled state visually.
  - Use `@FocusedValue` to expose `hasCompiledIcon` to the command. This is the SwiftUI-native pattern.
- Prefer `@FocusedValue`. If it doesn't work cleanly for this structure, lift into an `@Observable` shared state.

## Out of Scope

- Renaming `compile()` to `build()` in the code (file as a separate refactor if desired).
- Moving other toolbar actions to menu items.
- Customizing menu ordering beyond putting Build/Export in the File menu.
