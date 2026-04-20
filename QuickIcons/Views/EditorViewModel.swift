//
//  EditorViewModel.swift
//  QuickIcons
//

import AppKit
import Foundation
import SwiftUI

/// Owns the editor's compile/export lifecycle and UI-adjacent state.
///
/// `EditorViewModel` is the single source of truth for source text, compile
/// output, preview image, and export messaging. It is `@Observable` so SwiftUI
/// views (e.g. ``EditorView``) can bind to its properties via `@Bindable`.
///
/// Services (``SwiftCompilerService``, ``IconPreviewService``,
/// ``IconExportService``, ``DylibSession``) are injected through the
/// initializer so tests can substitute fakes. All services and state mutation
/// run on the main actor — compile/export paths touch AppKit panels and
/// SwiftUI image rendering.
@MainActor
@Observable
final class EditorViewModel {

    // MARK: - Editor state

    var sourceCode: String
    var fontSize: CGFloat = 13
    var showsInvisibles: Bool = false

    // MARK: - Compile lifecycle

    var isCompiling: Bool = false
    var compiledDylibURL: URL?
    var compileError: String?
    var compiledImage: NSImage?
    var hasCompiledIcon: Bool = false

    // MARK: - Export lifecycle

    var exportMessage: ExportMessage?

    // MARK: - Diagnostics availability

    /// `true` when the most recent sourcekitd diagnostics request failed
    /// (crash, timeout, missing toolchain, malformed response). The editor
    /// surfaces a subtle "diagnostics unavailable" toolbar affordance while
    /// this is set so users can distinguish clean code from a broken toolchain.
    var diagnosticsUnavailable: Bool = false

    // MARK: - Services

    private let compiler: SwiftCompilerService
    private let previewer: IconPreviewService
    private let exporter: IconExportService
    private let dylibSession: DylibSession

    // MARK: - Init

    /// Creates a view model with the given services and initial source.
    ///
    /// Defaults construct a shared ``DylibSession`` used by both the previewer
    /// and the export path so they return consistent symbols for a given
    /// dylib URL.
    init(
        sourceCode: String? = nil,
        compiler: SwiftCompilerService? = nil,
        dylibSession: DylibSession? = nil,
        previewer: IconPreviewService? = nil,
        exporter: IconExportService? = nil
    ) {
        let session = dylibSession ?? DylibSession()
        self.sourceCode = sourceCode ?? EditorViewModel.defaultSourceCode
        self.compiler = compiler ?? SwiftCompilerService()
        self.dylibSession = session
        self.previewer = previewer ?? IconPreviewService(session: session)
        self.exporter = exporter ?? IconExportService()
    }

    // MARK: - Source change

    /// Invalidates the compiled-icon flag when the user edits source.
    /// `EditorView` calls this from `.onChange(of: sourceCode)`.
    func sourceCodeChanged() {
        hasCompiledIcon = false
    }

    // MARK: - Zoom / invisibles

    func zoomIn() { fontSize = min(fontSize + 1, 36) }
    func zoomOut() { fontSize = max(fontSize - 1, 9) }
    func resetZoom() { fontSize = 13 }
    func toggleInvisibles() { showsInvisibles.toggle() }

    // MARK: - Open file

    /// Loads Swift source from `url` into ``sourceCode``. Presents an NSAlert
    /// describing any read error and leaves existing source untouched.
    func openFile(at url: URL) {
        do {
            sourceCode = try readSwiftSource(at: url)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could Not Open File"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Compile

    /// Compiles the current ``sourceCode`` and, on success, renders the preview
    /// image. On failure, sets ``compileError`` to the first diagnostic.
    func compile() async {
        isCompiling = true
        compileError = nil
        exportMessage = nil

        let result = await compiler.compile(source: sourceCode)

        switch result {
        case .success(let dylibURL):
            compiledDylibURL = dylibURL
            compiledImage = previewer.render(dylibURL: dylibURL, size: 400)
            hasCompiledIcon = true
        case .failure(let diagnostics):
            compiledDylibURL = nil
            compiledImage = nil
            hasCompiledIcon = false
            if let first = diagnostics.first(where: { $0.severity == .error }) ?? diagnostics.first {
                compileError = "Error on line \(first.line): \(first.message)"
            } else {
                compileError = "Compilation failed with unknown error."
            }
        }

        isCompiling = false
    }

    // MARK: - Export

    /// Prompts the user for a destination directory and writes an
    /// `AppIcon.appiconset` bundle there using the currently compiled dylib.
    ///
    /// No-ops (with an error message) if called before a successful compile.
    func export() {
        guard let dylibURL = compiledDylibURL else {
            exportMessage = .error("Compile the icon first before exporting.")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose the directory to export the AppIcon.appiconset bundle into."

        guard panel.runModal() == .OK, let baseURL = panel.url else { return }

        let factory: IconFactory
        do {
            factory = try dylibSession.loadIcon(at: dylibURL)
        } catch {
            exportMessage = .error("Could not load the compiled icon. Try building again.")
            return
        }

        do {
            let destination = try exporter.export(
                viewFactory: { factory.view(size: $0) },
                name: "AppIcon",
                to: baseURL
            )
            exportMessage = .success(destination.path)
        } catch {
            exportMessage = .error(error.localizedDescription)
        }
    }
}

// MARK: - Export message

/// Result of the most recent export attempt, surfaced in the preview panel.
enum ExportMessage: Equatable {
    case success(String)
    case error(String)
}

// MARK: - Default source

extension EditorViewModel {
    /// Starter `IconView` the editor opens with.
    static let defaultSourceCode: String = """
    import SwiftUI

    struct IconView: View {
        var size: CGFloat

        var body: some View {
            ZStack {
                Color.iconBackground

                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.175), Color.iconBackground]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 2)

                Group {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: size * 0.8))
                        .fontWeight(.thin)
                        .foregroundStyle(Color.bookmark)
                        .overlay(
                            LinearGradient(
                                colors: [Color.red.opacity(0.05), Color.red.opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .mask {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: size * 0.8))
                                    .fontWeight(.thin)
                            }
                        )

                    Image(systemName: "text.quote")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.black.opacity(0.8))
                        .offset(y: -size * 0.1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: max(size * 0.025, 10), style: .circular))
            .frame(width: size, height: size)
        }
    }

    extension Color {
        static let iconBackground = Color.black
        static let bookmark = Color.yellow
    }
    """
}
