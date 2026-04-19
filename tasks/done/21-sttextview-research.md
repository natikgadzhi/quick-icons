---
dependencies: []
status: backlog
---

# STTextView Usage Audit + Syntax Highlighting + Completions Research

## Objective

Deep-dive research task (no code changes). Produce a written analysis + a small set of concrete, prioritized follow-up tasks. Runs with Opus, high effort.

Three strands:

1. **How QuickIcons uses STTextView vs. how Marcin Krzyżanowski uses it in Notepad.exe.** Identify everything we're leaving on the table — gutter configuration, line highlight, selection handling, plugin composition, undo stack, typing attributes, font scaling, keyboard handling, `NSLayoutManager` vs. TextKit 2 settings, etc.

2. **Why our syntax highlighting looks weaker than Xcode's.** Catalog the specific gaps — token coverage (are we hitting all semantic kinds?), color correctness across Xcode themes, italic/bold for comments/keywords, attribute invalidation ranges on edits, performance on large files, tree-sitter grammar version we're pinned to, whether we're missing any Plugin-Neon configuration knobs.

3. **Completions (Xcode-style).** Assess feasibility of code completion as the user types. Cover:
   - Available mechanisms: SourceKit `source.request.codecomplete` via SourceKittenFramework (we already have it in the project), vs. SwiftSyntax-based local completions, vs. sourcekit-lsp.
   - Integration cost with STTextView — does Plugin-Neon expose a completion hook, or do we need a custom plugin?
   - UX: completion popup widget (built-in `NSTextView` completion vs. custom), ranking, snippet insertion, dismissal semantics.
   - Perf cost: SourceKit completion request latency, typical cache size, acceptable debounce window.
   - Honest verdict: is this a weekend polish or a multi-week yak shave?

## Reference Material

- Upstream: https://github.com/krzyzanowskim/STTextView
- Notepad.exe (Marcin's demo app): https://github.com/krzyzanowskim/Notepad.exe
- Plugin-Neon: https://github.com/krzyzanowskim/STTextView-Plugin-Neon
- Plugin-Annotations: https://github.com/krzyzanowskim/STTextView-Plugin-Annotations
- SourceKitten: https://github.com/jpsim/SourceKitten
- Our current wiring: `QuickIcons/Views/STTextViewRepresentable.swift`, `QuickIcons/Views/XcodeColorTheme.swift`, `QuickIcons/Services/SourceKitDiagnosticsService.swift`

Cross-reference the checked-out SPM sources under `~/Library/Developer/Xcode/DerivedData/QuickIcons-*/SourcePackages/checkouts/` for exact API surface.

## Deliverable

A written analysis (markdown, in this task's PR or as a follow-up `docs/sttextview-audit.md`) covering:

- Side-by-side table: Notepad.exe features vs. what we have
- Concrete list of missing Plugin-Neon / STTextView knobs we should enable
- Root cause of our weaker highlighting (specifically — which tokens or scopes are missing colors, or is the tree-sitter query too narrow?)
- Completions feasibility verdict: `ship in N days` / `multi-week` / `not worth it`, with reasoning
- 3–5 concrete follow-up tasks with rough sizing (S/M/L)

## Notes

- This is a research task. **Do not modify app code** aside from temporary exploration. If you need to test something, write a throwaway script in `scratch/`.
- Budget: one focused session. Stop at the writeup.
- Use the `swiftui-pro` and `swift-concurrency-pro` skills if relevant while auditing.

## PR

https://github.com/natikgadzhi/quick-icons/pull/33 — `docs/sttextview-audit.md`
