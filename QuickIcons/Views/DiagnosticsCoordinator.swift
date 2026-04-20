//
//  DiagnosticsCoordinator.swift
//  QuickIcons
//
//  Owns everything the editor needs to turn a SourceKit diagnostics result
//  into on-screen annotations + gutter markers:
//   - a single Task that debounces per keystroke (700 ms),
//   - the async service call,
//   - projection to STAnnotationsPlugin annotations,
//   - gutter marker bookkeeping (install / remove our own markers without
//     clobbering user-added ones),
//   - an availability callback that fires only when the sourcekitd reachable
//     state flips (so the UI can surface a "diagnostics unavailable" hint
//     without being spammed on every keystroke).
//
//  This is intentionally not an NSViewRepresentable.Coordinator — it is a
//  plain `@MainActor` helper owned by STTextViewRepresentable.Coordinator so
//  the two concerns (diagnostics vs. text binding / auto-indent) stay
//  separate and each stays testable with a mock service.
//

import AppKit
import STAnnotationsPlugin
import STTextView

/// Minimal surface the diagnostics coordinator needs from its service.
/// Declaring it here lets tests inject a mock without touching the concrete
/// `SourceKitDiagnosticsService` definition. The return type matches the
/// service's `DiagnosticsResult` (either diagnostics on success, or an error
/// when sourcekitd is unavailable) so the coordinator can drive the UI's
/// availability affordance.
@MainActor
protocol DiagnosticsProviding {
    nonisolated func diagnostics(for source: String) async -> DiagnosticsResult
}

extension SourceKitDiagnosticsService: DiagnosticsProviding {}

/// Coordinates diagnostics requests and their visual output for a single
/// STTextView. Instances are created by `STTextViewRepresentable.Coordinator`
/// and live as long as the text view's coordinator does.
@MainActor
final class DiagnosticsCoordinator {

    /// Reference to the annotations plugin — installed by
    /// `STTextViewRepresentable.makeNSView` once the plugin has been added
    /// to the text view. Setting `textViewAnnotations` triggers a reload.
    weak var annotationsPlugin: STAnnotationsPlugin?

    /// Current annotations shown in the text view. Assigning here tells the
    /// plugin to reload its visible annotations.
    var textViewAnnotations: [any STLineAnnotation] = [] {
        didSet {
            annotationsPlugin?.reloadAnnotations()
        }
    }

    /// Line numbers (1-based) for gutter markers we installed from the
    /// latest diagnostics batch. Tracked separately so subsequent updates
    /// can remove only our markers without clobbering user-added ones.
    private var diagnosticMarkerLines: Set<Int> = []

    /// The pending diagnostics task. Cancelled and replaced on each keystroke.
    private var diagnosticsTask: Task<Void, Never>?

    private let service: any DiagnosticsProviding
    private let debounce: Duration

    /// Host-supplied callback that fires when sourcekitd availability flips.
    private let onAvailabilityChange: ((Bool) -> Void)?

    /// Last reported availability state — used to debounce the callback so a
    /// streak of successful (or failing) keystrokes doesn't fire it on every
    /// one.
    private var diagnosticsUnavailable: Bool = false

    init(
        service: any DiagnosticsProviding,
        debounce: Duration = .milliseconds(700),
        onAvailabilityChange: ((Bool) -> Void)? = nil
    ) {
        self.service = service
        self.debounce = debounce
        self.onAvailabilityChange = onAvailabilityChange
    }

    /// Convenience initializer that wires up the default concrete service.
    /// Separate entry point (instead of a default argument) so the
    /// service's initializer runs in the MainActor-isolated body — default
    /// arguments adopt the caller's isolation, which isn't always MainActor.
    convenience init(
        debounce: Duration = .milliseconds(700),
        onAvailabilityChange: ((Bool) -> Void)? = nil
    ) {
        self.init(
            service: SourceKitDiagnosticsService(),
            debounce: debounce,
            onAvailabilityChange: onAvailabilityChange
        )
    }

    deinit {
        diagnosticsTask?.cancel()
    }

    /// Schedule a debounced diagnostics request for `textView`'s current
    /// contents. Cancels any in-flight request first.
    ///
    /// 700 ms is long enough to absorb a `.` plus the next identifier
    /// character without flashing a spurious error.
    func scheduleDiagnostics(for textView: STTextView) {
        diagnosticsTask?.cancel()
        let debounce = self.debounce
        diagnosticsTask = Task { [weak self, weak textView] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                // Cancelled — a newer keystroke supersedes this one.
                return
            }

            guard let self, !Task.isCancelled else { return }

            let source = textView?.text ?? ""
            let result = await self.service.diagnostics(for: source)

            guard !Task.isCancelled, let textView else { return }

            switch result {
            case .success(let diagnostics):
                self.updateAvailability(unavailable: false)
                self.applyDiagnostics(diagnostics, to: textView)
            case .failure:
                // Toolchain / sourcekitd failure: clear any stale markers and
                // notify the host so it can surface an affordance.
                self.updateAvailability(unavailable: true)
                self.applyDiagnostics([], to: textView)
            }
        }
    }

    /// Synchronously project `diagnostics` into annotations + gutter markers
    /// for `textView`. Public so tests (and the scheduler above) can drive it
    /// without going through the debounce.
    func applyDiagnostics(_ diagnostics: [SwiftDiagnostic], to textView: STTextView) {
        let source = textView.text ?? ""
        let annotations: [any STLineAnnotation] = diagnostics.compactMap { diagnostic in
            guard let location = textLocation(forLine: diagnostic.line, in: source, textView: textView) else {
                return nil
            }

            let kind: STMessageLineAnnotation.AnnotationKind = switch diagnostic.severity {
            case .error: .error
            case .warning: .warning
            case .note: .info
            }

            return STMessageLineAnnotation(
                id: "\(diagnostic.line):\(diagnostic.column):\(diagnostic.message)",
                message: AttributedString(diagnostic.message),
                kind: kind,
                location: location
            )
        }
        textViewAnnotations = annotations

        applyGutterMarkers(for: diagnostics, to: textView)
    }

    /// Installs a colored dot marker in the gutter for each diagnostic line.
    /// The most severe diagnostic on a given line wins (error > warning > note).
    /// Markers from the previous batch are removed before the new ones are
    /// installed, so the pass is idempotent across keystrokes.
    func applyGutterMarkers(for diagnostics: [SwiftDiagnostic], to textView: STTextView) {
        guard let gutter = textView.gutterView else { return }

        for line in diagnosticMarkerLines {
            gutter.removeMarker(lineNumber: line)
        }
        diagnosticMarkerLines.removeAll(keepingCapacity: true)

        let worstByLine = TextOffset.mostSevereByLine(diagnostics)
        for (line, severity) in worstByLine {
            let markerView = DiagnosticMarkerView(severity: severity)
            gutter.addMarker(STGutterMarker(lineNumber: line, view: markerView))
            diagnosticMarkerLines.insert(line)
        }
    }

    /// Lines currently marked in the gutter from the latest diagnostics batch.
    /// Exposed for tests that want to assert our bookkeeping is clean.
    var installedMarkerLines: Set<Int> { diagnosticMarkerLines }

    /// Current availability state — exposed for tests.
    var isDiagnosticsUnavailable: Bool { diagnosticsUnavailable }

    /// Fires the availability callback only when the state flips, so a
    /// streak of successful (or failing) keystrokes doesn't spam the host.
    private func updateAvailability(unavailable: Bool) {
        guard diagnosticsUnavailable != unavailable else { return }
        diagnosticsUnavailable = unavailable
        onAvailabilityChange?(unavailable)
    }

    /// Converts a 1-based line number to an `NSTextLocation` inside the
    /// document, or `nil` when the line is out of range.
    private func textLocation(
        forLine line: Int,
        in source: String,
        textView: STTextView
    ) -> (any NSTextLocation)? {
        guard line >= 1 else { return nil }

        let utf16Offset = TextOffset.utf16Offset(forLine: line, in: source)
        guard utf16Offset >= 0 else { return nil }

        return textView.textLayoutManager.location(
            textView.textLayoutManager.documentRange.location,
            offsetBy: utf16Offset
        )
    }
}
