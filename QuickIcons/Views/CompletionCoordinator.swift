//
//  CompletionCoordinator.swift
//  QuickIcons
//
//  Owns everything the editor needs to drive STTextView's async completion
//  hook:
//   - a single Task that debounces per keystroke (200 ms),
//   - the sourcekitd round-trip via `SourceKitCompletionService`,
//   - identifier-prefix math that decides how much of the caret-adjacent
//     word to replace,
//   - post-insert placeholder selection (Xcode-style argument tab stop).
//
//  Like DiagnosticsCoordinator, this is not an NSViewRepresentable.Coordinator
//  — it is a plain `@MainActor` helper owned by the real Coordinator.
//

import AppKit
import STTextView
import STTextKitPlus

/// Minimal surface the completion coordinator needs from its service.
/// Declared here so tests can inject a mock without touching the concrete
/// `SourceKitCompletionService` definition.
@MainActor
protocol CompletionProviding {
    nonisolated func complete(source: String, offset: Int) async throws -> [SwiftCompletionItem]
}

extension SourceKitCompletionService: CompletionProviding {}

/// Coordinates code-completion requests and insertion for a single STTextView.
@MainActor
final class CompletionCoordinator {

    /// The pending completion task. Cancelled and replaced on each keystroke,
    /// and automatically torn down when this coordinator deallocates.
    private var completionTask: Task<[any STCompletionItem]?, Never>?

    private let service: any CompletionProviding
    private let debounce: Duration

    init(
        service: any CompletionProviding,
        debounce: Duration = .milliseconds(200)
    ) {
        self.service = service
        self.debounce = debounce
    }

    /// Convenience initializer that wires up the default concrete service.
    /// Separate entry point (instead of a default argument) so the
    /// MainActor-isolated `SourceKitCompletionService()` call happens in the
    /// MainActor-isolated body, not at an arbitrary call-site isolation.
    convenience init(debounce: Duration = .milliseconds(200)) {
        self.init(service: SourceKitCompletionService(), debounce: debounce)
    }

    deinit {
        completionTask?.cancel()
    }

    /// Produce completion items for `textView` at `location`. Cancels any
    /// in-flight request first; 200 ms debounce matches the spec.
    func completionItems(
        for textView: STTextView,
        at location: any NSTextLocation
    ) async -> [any STCompletionItem]? {
        let source = textView.text ?? ""
        let utf16Offset = textView.textLayoutManager.offset(
            from: textView.textLayoutManager.documentRange.location,
            to: location
        )
        guard utf16Offset >= 0 else { return nil }
        let byteOffset = TextOffset.utf8ByteOffset(forUTF16Offset: utf16Offset, in: source)

        completionTask?.cancel()
        let debounce = self.debounce
        let service = self.service
        let task = Task { () -> [any STCompletionItem]? in
            // 200 ms — matches the spec; diagnostics use 700 ms because error
            // annotations are higher-cost / noisier than a completion list.
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return nil
            }
            if Task.isCancelled { return nil }

            do {
                let items = try await service.complete(source: source, offset: byteOffset)
                if Task.isCancelled { return nil }
                return items.map { SwiftCompletionListItem(item: $0) }
            } catch {
                return nil
            }
        }
        completionTask = task
        return await task.value
    }

    /// Insert the selected completion into `textView`, replacing the
    /// identifier prefix the user already typed at the caret with the item's
    /// `plainInsertText`. Placeholder markers (`<#…#>`) are stripped to their
    /// visible labels; the first placeholder is selected so the user can type
    /// over it immediately (Xcode-style "argument tab stop" behavior, minus
    /// the rich snippet UI which STTextView does not yet support).
    func insertCompletionItem(_ item: any STCompletionItem, into textView: STTextView) {
        guard let completion = item as? SwiftCompletionListItem else { return }
        let insertText = completion.plainInsertText
        guard !insertText.isEmpty else { return }

        let source = textView.text ?? ""
        let caretLocation = textView.textLayoutManager.insertionPointLocations.first
            ?? textView.textLayoutManager.textSelections.first?.textRanges.first?.endLocation
            ?? textView.textLayoutManager.documentRange.location
        let caretUTF16 = textView.textLayoutManager.offset(
            from: textView.textLayoutManager.documentRange.location,
            to: caretLocation
        )
        let prefixLength = TextOffset.identifierPrefixLength(
            in: source,
            endingAtUTF16Offset: caretUTF16
        )

        // Replace [caret - prefix, caret) with the plain insert text.
        let replacementStartUTF16 = caretUTF16 - prefixLength
        guard replacementStartUTF16 >= 0,
              let replacementStart = textView.textLayoutManager.location(
                textView.textLayoutManager.documentRange.location,
                offsetBy: replacementStartUTF16
              ),
              let replacementRange = NSTextRange(
                location: replacementStart,
                end: caretLocation
              ) else {
            // Fallback: just insert at the current selection.
            textView.insertText(insertText, replacementRange: textView.selectedRange())
            return
        }

        textView.replaceCharacters(in: replacementRange, with: insertText)

        // If the insert contains a placeholder, select its label so the user
        // can type over it. Otherwise, leave the caret at the end.
        if let placeholderRange = completion.firstPlaceholderUTF16Range,
           let selectionStart = textView.textLayoutManager.location(
            replacementStart,
            offsetBy: placeholderRange.lowerBound
           ),
           let selectionEnd = textView.textLayoutManager.location(
            replacementStart,
            offsetBy: placeholderRange.upperBound
           ),
           let selectionRange = NSTextRange(location: selectionStart, end: selectionEnd) {
            textView.textLayoutManager.textSelections = [
                NSTextSelection(
                    range: selectionRange,
                    affinity: .downstream,
                    granularity: .character
                )
            ]
        }
    }
}
