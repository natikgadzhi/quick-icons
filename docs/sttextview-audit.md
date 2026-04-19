# STTextView Audit + Syntax Highlighting + Completions Feasibility

_Research writeup for task 21. No code changes; recommendations land as follow-up tasks._

## 1. STTextView Usage: QuickIcons vs. Upstream Demos

**Note:** Marcin's `Notepad.exe` is a private/paid app and not on GitHub. The closest
public references are the `STTextView/TextEdit/Mac/PrimaryTextEditViewController.swift`
demo and the `STTextView-Plugin-Neon/DemoApp/EditorViewController.swift` demo; both
ship in the SPM checkouts under DerivedData. I used those as the comparison baseline.

### Feature matrix

| Capability | STTextView API | Demo(s) | QuickIcons today |
| --- | --- | --- | --- |
| Line-number gutter | `showsLineNumbers` | yes | yes |
| Gutter separator | `gutterView?.drawSeparator` | yes (TextEdit) | **no** |
| Gutter breakpoint/diagnostic markers | `gutterView?.areMarkersEnabled` | yes (TextEdit) | **no** |
| Gutter highlight current line | `gutterView?.highlightSelectedLine` | yes (Plugin-Neon demo toggle) | **no** |
| Gutter font / insets / min thickness | `gutterView?.font/insets/minimumThickness` | default | default |
| Selected-line highlight (body) | `highlightSelectedLine` | yes | yes |
| Soft-wrap vs. horizontal scroll | `isHorizontallyResizable` | toggle (menu item) | fixed off |
| Invisible characters (⇥, ⏎, ·) | `showsInvisibleCharacters` | toggle | **no** |
| Incremental search (⌘F) | `isIncrementalSearchingEnabled` | yes | **no** |
| Line-height multiple | `defaultParagraphStyle` + `NSMutableParagraphStyle.lineHeightMultiple = 1.2` | yes in both demos | **no** (cramped default) |
| Spell/grammar check | `isContinuousSpellCheckingEnabled`, `isGrammarCheckingEnabled` | off | default (off) |
| Typing attributes reset | `resetTypingAttributes()` | n/a | n/a |
| Completion (built-in window) | `complete(_:)` + `STTextViewDelegate.completionItemsAtLocation` (sync + async) | yes (word tokenizer) | **no** |
| Completion dismiss on selection change | `shouldDimissCompletionOnSelectionChange` | default | n/a |
| Text attachments / links / custom cursors | `addAttributes([.link:], [.cursor:]) `, `NSTextAttachment` | yes | **no** |
| Neon plugin | `NeonPlugin(theme:language:)` | yes | yes |
| Annotations plugin | `STAnnotationsPlugin` | — | yes (diagnostics) |
| Custom paragraph line spacing | `defaultParagraphStyle` | yes | **no** |
| Undo stack | Built in | default | default |

### Concrete missing knobs we should set today

Small, obvious wins in `STTextViewRepresentable.makeNSView`:

- `textView.defaultParagraphStyle` with `lineHeightMultiple = 1.2` (both demos do this; matches Xcode's breathing room).
- `textView.gutterView?.drawSeparator = true`
- `textView.gutterView?.highlightSelectedLine = true` (Xcode-style highlighted line number)
- `textView.gutterView?.areMarkersEnabled = true` (enables breakpoint-style markers; useful once diagnostics grow)
- `textView.isIncrementalSearchingEnabled = true` (⌘F Find bar works out of the box)
- `textView.showsInvisibleCharacters` — toggleable via a View menu item (we already have nothing there; a simple `@AppStorage` boolean would do).
- `textView.usesFontPanel = false` — we don't want the font panel hijacking ⌘T.

Two more worth evaluating:

- `textView.shouldDimissCompletionOnSelectionChange = true` (default is already true but document intent once we add completions).
- `textView.isContinuousSpellCheckingEnabled` — keep **off** for code; explicit.

## 2. Why our syntax highlighting looks weaker than Xcode

Root cause is a combination of three issues, in order of impact.

### 2.1. Our theme dictionary is missing more than half of the capture scopes

`Package.resolved` pins `STTextView-Plugin-Neon` at `5a30db4` (no semver — Marcin
branch-pins). The vendored `TreeSitterSwiftQueries/highlights.scm` emits **28
distinct captures**:

```
@boolean @comment @conditional @constructor @float @function.call
@function.macro @include @keyword @keyword.function @keyword.operator
@keyword.return @label @method @number @operator @parameter @property
@punctuation.bracket @punctuation.delimiter @punctuation.special @repeat
@spell @string @string.regex @type @variable @variable.builtin
```

Our `Theme.Colors.xcode` only maps **20** of those, and many to the wrong color.
Missing captures fall through to `"plain"` via Neon's fallback in
`STTextView-Plugin-Neon/Sources/STPluginNeonAppKit/Coordinator.swift` — which is
exactly why so many things render in the default text color.

Concrete gaps and suggested Xcode-matching colors (light / dark hex, Xcode
"Default (Light/Dark)" palette; derived from the `NSColor.xcodeToken` helper already
in `XcodeColorTheme.swift`):

| Scope | Current | What Xcode does | Suggested mapping |
| --- | --- | --- | --- |
| `conditional` (`if`/`else`/`switch`/`case`/`guard`/`where`) | falls through to plain | bold magenta keyword | `keyword` color, medium |
| `repeat` (`for`/`while`/`repeat`) | plain | bold magenta keyword | `keyword` color, medium |
| `keyword.operator` (`is`/`as`/`try`) | plain | bold magenta keyword | `keyword` color, medium |
| `function.macro` (`@MainActor`, `#file`, `#warning`) | plain | purple-ish attribute color `#804FB8 / #FFA14F` | new "macro" color |
| `property` (struct/class member refs) | plain | Xcode uses `#326D74 / #67B7A4` for instance properties | new "property" color |
| `method` | mapped to **plain** | Xcode uses `#272AD8 / #41A1C0` for project methods — we treat it like a plain var | remap to function color (not plain) |
| `function.call` | mapped to **plain** | Xcode uses the same "project function" tint | remap to function color |
| `constructor` | mapped to **type** | correct-ish; Xcode uses the same purple | keep |
| `float` | unset — inherits plain | Xcode same as integer | map to `number` |
| `string.regex` | unset | Xcode uses its own regex color (`#4C4C6A / #B89EF8`) | new color, or reuse `string` |
| `label` (`outer:` in `break outer`) | unset | label color | fall back to `plain` ok |
| `punctuation.bracket` / `.delimiter` | unset | stays plain in Xcode | OK to leave |
| `variable.builtin` (`self`, `super`) | mapped to plain | Xcode **bolds** them in magenta | `keyword` color, medium |

Impact: our editor looks flatter than Xcode because **identifiers, method names,
control-flow keywords, macros, and builtins all render in one foreground color**.

### 2.2. `locals.scm` is shipped but never loaded

`TreeSitterSwiftQueries/locals.scm` ships alongside `highlights.scm`.
`STTextView-Plugin-Neon/Sources/TreeSitterResource/TreeSitterLanguage.swift` exposes
`localsQueryURL`, but `Coordinator.swift:81` only loads `highlightQueryURL!`. That
means scope-aware token disambiguation (local var vs. type in a parameter list) is
off. We can't fix this from our side without a fork of Plugin-Neon or a custom
plugin that wires the TreeSitterClient directly.

### 2.3. Neon's `clearStyle` is asymmetric — it only clears `.foregroundColor`

```swift
func clearStyle(in range: NSRange) {
    textView.textLayoutManager.removeRenderingAttribute(.foregroundColor, for: textRange)
    textView.addAttributes([.font: textView.font], range: range)
}
```

It resets the **font** to `textView.font` — fine when we use a single weight — but
it only removes `.foregroundColor` as a rendering attribute. This means anything
we attach via `attributes[.underlineStyle] = ...` or `.backgroundColor` will
stick after edits. Not a bug we hit today, but it constrains future work (error
squiggles as rendering attributes would need us to clear them ourselves on edit).

### 2.4. Tree-sitter-swift grammar is vendored as raw C

`TreeSitterSwift/src/parser.c` declares `LANGUAGE_VERSION 14`, `STATE_COUNT 6344`,
`SYMBOL_COUNT 500`. This matches roughly `alex-pinkus/tree-sitter-swift` from
early 2024. There's no git hash in the vendored copy. Notably **no
`injections.scm`** is present for Swift, so string-interpolation bodies and
multi-line-string DSL bodies (SwiftUI `View` builders) stay as plain strings.
Upstream tree-sitter-swift still doesn't ship one either — fixing this means a
custom injections query, not a version bump.

### 2.5. Full-document re-read on every keystroke

`Coordinator.didChangeContent` calls
`textContentManager.attributedString(in: nil)?.string` on every edit (TODO comment
from Marcin acknowledges this). For our icon-scripting use case this is fine (few
KB). Not a correctness issue; flag for awareness.

## 3. Xcode-style Completions: Feasibility

STTextView already ships a **fully functional completion UI**:
`STTextView+Complete.swift`, `STCompletionWindowController`, and an async
delegate hook `textView(_:completionItemsAtLocation:) async -> [any STCompletionItem]?`.
We implement that delegate and return items; the window positioning,
keyboard navigation, dismissal, and insertion flow are free. Our job is strictly
**generating the completion list**.

### Option A — SourceKit `source.request.codecomplete` via SourceKittenFramework

- **Already in `Package.resolved`**: SourceKitten 0.37.3.
- Request key: `SourceKittenFramework.Request` supports `codecomplete` directly
  (`Request.swift:203`); `CodeCompletionItem.parse(response:)` returns an array
  with `kind`, `name`, `descriptionKey`, `sourcetext` (insert text with
  placeholder snippets), `typeName`, `moduleName`, `docBrief`, `associatedUSRs`.
- **Input requirements:** like our existing diagnostics service, it needs a path
  on disk + compiler args + an offset (UTF-8 byte offset of the cursor). We
  already write to a temp file in `SourceKitDiagnosticsService` — can reuse that
  pattern.
- **Latency:** the first completion request per sourcekitd session is slow
  (~300–900 ms on M-series: process spawn + SDK load). Subsequent ones are
  typically 30–80 ms for a small file. We already pay the first-hit cost for
  diagnostics, so the second subsystem piggybacks on a warm sourcekitd.
- **Caching:** sourcekitd caches the AST keyed by compiler args + file; results
  for the same cursor position are near-instant. A 150–200 ms debounce on
  typing is the right ergonomic window.
- **Integration cost:** one Service (`SourceKitCompletionService`), one
  delegate method, one `STCompletionItem` conformance. Roughly ~250 LOC + tests.
- **UX wins:** real symbol kinds (function/property/enum-case icons via SF
  Symbols), `sourcetext` includes `<#placeholder#>` snippets (we can map those
  to simple insertion or fancier snippet navigation later), `typeName` gives us
  the "-> T" trailing annotation Xcode shows.
- **UX risks:** a scratch `.swift` file with `-sdk` and module name only exposes
  symbols from stdlib + Foundation + whatever the user explicitly `import`s.
  That's fine for our use case (SwiftUI icon scripts), but no cross-file
  awareness.

### Option B — sourcekit-lsp

- Full LSP protocol, cross-file awareness, matches what Xcode/VSCode use.
- Requires us to manage an LSP subprocess, initialize workspace, send text
  sync notifications (`textDocument/didOpen`, `didChange`), handle cancellation,
  parse `CompletionItem`s.
- **Integration cost:** 1–2 weeks just to get basics working, plus ongoing
  maintenance (LSP spec drift, sourcekit-lsp version pinning).
- **Latency:** similar once warm; cold start is worse (~1–2 s).
- **Value over Option A:** nearly none for icon scripts (single-file editor
  with no project). Not worth it.

### Option C — SwiftSyntax-local (AST-walk the document, offer symbols in scope)

- Zero subprocess, fastest (<10 ms for our file sizes), but no stdlib
  knowledge — we'd only surface identifiers the user has already typed plus a
  hand-maintained list of common APIs (`View`, `ZStack`, `Color`, ...).
- Approximates word-completion like the STTextView demo does.
- **Integration cost:** ~2–3 days, but quality tops out at "decent word
  completer". Not a real Xcode substitute.
- Useful as a **fallback** while sourcekitd is warming up.

### Verdict

**Ship in 1–2 weeks.** Option A (SourceKit via SourceKitten) is the right bet.
We already have the toolchain, the subsystem, the IPC, and STTextView's
completion UI. The only real work is:

1. A `SourceKitCompletionService` mirroring `SourceKitDiagnosticsService`.
2. An `STCompletionItem` wrapper with an SF-Symbol view for kind.
3. Wire `textView(_:completionItemsAtLocation:) async` in the coordinator with
   200 ms debounce + Task cancellation.
4. A trigger policy: show on `.` / after 2 chars of an identifier / ⌃Space
   explicit; dismiss on space/newline/punctuation.

Not weekend because of the testing/polish surface (snippet placeholder
handling, kind-to-icon mapping, ranking, warm-start UX). Not multi-week
because the infrastructure lands in small, independent PRs.

## 4. Prioritized Follow-ups

Ordered by value/effort ratio.

| Priority | Task | Size | Why |
| --- | --- | --- | --- |
| 1 | **Expand `XcodeColorTheme` to cover all 28 Swift captures + fix `method`/`function.call` miscolor.** Add `conditional`, `repeat`, `keyword.operator`, `function.macro`, `property`, `float`, `string.regex`, `variable.builtin`. Retint `method`/`function.call` to Xcode's function-call blue. | **S** (half-day) | Biggest visible "feels like Xcode" win. Pure data change inside `Theme.Colors.xcode`. |
| 2 | **Enable the free STTextView knobs.** Line-height 1.2 paragraph style, gutter separator, gutter selected-line highlight, gutter markers enabled, `isIncrementalSearchingEnabled`, toggleable `showsInvisibleCharacters` menu item, `usesFontPanel = false`. | **S** (half-day) | One file (`STTextViewRepresentable.swift`) + one menu command. High polish yield, near-zero risk. |
| 3 | **Add SourceKit-backed code completion.** New `SourceKitCompletionService`, `SwiftCompletionItem: STCompletionItem`, delegate wiring in `STTextViewRepresentable.Coordinator`. 200 ms debounce + Task cancellation mirroring the diagnostics path. | **L** (1–2 weeks, split into 3 PRs) | The marquee feature. Infrastructure already half-built by the diagnostics work. |
| 4 | **Fork/replace Plugin-Neon's Coordinator to load `locals.scm`.** Either vendor a thin `LocalNeonPlugin` in `QuickIcons/` that wires `TreeSitterClient` directly (keeping upstream for UIKit/iOS demos), or PR upstream. | **M** (2–3 days) | Improves type/variable disambiguation (`self.foo` vs. `foo`), matches Xcode's "instance property" color. Only worth doing after #1. |
| 5 | **Gutter visual polish: breakpoint-style error markers.** Hook `STGutterMarker` into the diagnostics pipeline so red dots show next to error lines (in addition to the inline annotation). | **M** (2 days) | Standard Xcode affordance; `areMarkersEnabled` gives us the hook for free once #2 lands. |

## 5. References

- `QuickIcons/Views/STTextViewRepresentable.swift` — our current wiring.
- `QuickIcons/Views/XcodeColorTheme.swift` — the 20-of-28 theme map.
- `QuickIcons/Services/SourceKitDiagnosticsService.swift` — reuse pattern for a
  completion service.
- SPM checkouts under `~/Library/Developer/Xcode/DerivedData/QuickIcons-*/SourcePackages/checkouts/`:
  - `STTextView/Sources/STTextViewAppKit/STTextView+Complete.swift`
  - `STTextView/Sources/STTextViewAppKit/STCompletion/*`
  - `STTextView/TextEdit/Mac/PrimaryTextEditViewController.swift` — richest demo; word-completion model mirrors what we want (replace word tokenizer with SourceKit).
  - `STTextView-Plugin-Neon/Sources/STPluginNeonAppKit/Coordinator.swift` — shows the full-doc re-read and the single-query load.
  - `STTextView-Plugin-Neon/Sources/TreeSitterSwiftQueries/highlights.scm` — authoritative capture list.
  - `SourceKitten/Source/SourceKittenFramework/Request.swift` + `CodeCompletionItem.swift` — codecomplete entry points.
- Tree-sitter-swift vendored in Plugin-Neon: `LANGUAGE_VERSION 14`, `SYMBOL_COUNT 500`. No upstream hash; no `injections.scm`.
