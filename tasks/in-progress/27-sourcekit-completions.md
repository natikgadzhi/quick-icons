---
dependencies: [06-swift-compiler-service, 25-expand-xcode-theme]
status: in-progress
---

## Pull Requests

- Stage 1 (service + tests): https://github.com/natikgadzhi/quick-icons/pull/37
- Stage 2 (delegate wiring + debounce + popup): https://github.com/natikgadzhi/quick-icons/pull/39

# SourceKit-backed Code Completion

## Objective

Wire Xcode-style code completion into the editor using SourceKit via
SourceKittenFramework (already pinned) and STTextView's built-in completion UI.

## Acceptance Criteria

- [ ] Typing triggers a completion popup after a 200ms debounce.
- [ ] Popup shows SourceKit completions — functions, types, properties,
      keywords — with kind-to-icon mapping (SF Symbols) and descriptions.
- [ ] Selecting an item inserts the completion, handling snippet-style
      placeholders for functions.
- [ ] Requests are cancelled when the user keeps typing (Task cancellation,
      mirroring the pattern in `SourceKitDiagnosticsService`).
- [ ] Popup follows the caret and dismisses on Escape / click elsewhere.
- [ ] Zero-warning build; unit tests for the completion service (with injected
      SourceKit request fixture or mock).

## Notes

- Split into 3 PRs for review ease:
  1. `SourceKitCompletionService` — isolated `source.request.codecomplete`
     wrapper with an injectable request runner and a typed
     `SwiftCompletionItem` value type. Unit-tested.
  2. Delegate wiring — `STTextViewRepresentable.Coordinator` conforms to the
     completion delegate
     (`STTextViewDelegate.textView(_:completionItemsAtLocation:) async -> [any STCompletionItem]?`).
     `SwiftCompletionItem: STCompletionItem`.
  3. Polish — icons, ranking, placeholder insertion, dismissal UX.
- STTextView already ships the popup window and controller: see
  `STTextView/Sources/STTextViewAppKit/STCompletion/*`.
- Size: L (1–2 weeks). Use `swift-concurrency-pro` and `swiftui-pro` skills.

## Out of Scope

- Cross-file / project-wide completion (single-file icon editor).
- Signature help / hover docs.
- sourcekit-lsp (rejected: too heavyweight for a single-file editor — see
  `docs/sttextview-audit.md` §3 Option B).
