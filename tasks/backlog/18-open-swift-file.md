---
dependencies: []
status: backlog
---

# Open Swift File Command (⌘O + File → Open)

## Objective

Add a command that lets the user open a `.swift` file from disk and load its contents into the editor, replacing whatever is currently in the buffer. The command should be available as:

- The `File → Open…` menu item (standard macOS placement)
- The keyboard shortcut `⌘O`

## Acceptance Criteria

- [ ] `File → Open…` menu item appears in the app's menu bar
- [ ] The menu item is bound to `⌘O`
- [ ] Selecting it presents an `NSOpenPanel` constrained to `.swift` files (`UTType.swiftSource`)
- [ ] On selection, the file's contents replace the current `sourceCode` in `EditorView`
- [ ] Reading fails gracefully with a user-visible message (not a crash) if the file is unreadable or isn't UTF-8
- [ ] The compile/preview state is reset as if the user typed the new source (i.e., `hasCompiledIcon` flips to false — per task 12)
- [ ] App builds with zero warnings; tests still pass

## Notes

- Use SwiftUI `.commands { CommandGroup(replacing: .newItem) { ... } }` on the `WindowGroup` to inject the menu item. `CommandMenu("File")` would create a duplicate; replace or append into the existing File menu.
- The simplest wiring: a `@FocusedObject` or a shared `EditorState` holding `sourceCode`. If that introduces too much plumbing, post a `Notification` from the command and observe it in `EditorView`.
- Keep this focused: one-way file → editor. No "Save" command in this task — file it separately if desired.
- No security-scoped bookmarks needed (sandbox is off per task 03).
