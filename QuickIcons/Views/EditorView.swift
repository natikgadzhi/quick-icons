import AppKit
import Darwin
import SwiftUI

private let defaultSourceCode = """
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

struct EditorView: View {
    @State private var sourceCode: String = defaultSourceCode
    @State private var compiledImage: NSImage?
    @State private var compileError: String?
    @State private var isCompiling = false
    @State private var compiledDylibURL: URL?
    @State private var exportMessage: ExportMessage?
    @State private var hasCompiledIcon = false
    @State private var showsInvisibles = false
    @State private var fontSize: CGFloat = 13

    private let compiler = SwiftCompilerService()
    private let previewer = IconPreviewService()
    private let exporter = IconExportService()

    var body: some View {
        GeometryReader { proxy in
            HSplitView {
                EditorPanel(sourceCode: $sourceCode, showsInvisibles: showsInvisibles, fontSize: fontSize)
                    .frame(
                        minWidth: 420,
                        idealWidth: proxy.size.width * 2 / 3,
                        maxWidth: .infinity
                    )
                PreviewPanel(
                    image: compiledImage,
                    errorMessage: compileError,
                    isCompiling: isCompiling,
                    exportMessage: $exportMessage
                )
                .frame(
                    minWidth: 300,
                    idealWidth: proxy.size.width / 3,
                    maxWidth: max(proxy.size.width / 2, 300)
                )
            }
        }
        .frame(minWidth: 1080, minHeight: 500)
        .onChange(of: sourceCode) { hasCompiledIcon = false }
        .focusedSceneValue(\.hasCompiledIcon, hasCompiledIcon)
        .focusedSceneValue(\.showsInvisibles, showsInvisibles)
        .onReceive(NotificationCenter.default.publisher(for: .openSwiftFileNotification)) { notification in
            if let source = notification.userInfo?[OpenSwiftFileNotification.sourceKey] as? String {
                sourceCode = source
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildRequested)) { _ in
            Task { await compile() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportRequested)) { _ in
            guard hasCompiledIcon else { return }
            export()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInvisibleCharacters)) { _ in
            showsInvisibles.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            fontSize = min(fontSize + 1, 36)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            fontSize = max(fontSize - 1, 9)
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetZoom)) { _ in
            fontSize = 13
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await compile() }
                } label: {
                    Label(
                        isCompiling ? "Building…" : "Build",
                        systemImage: isCompiling ? "hammer" : "hammer.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCompiling)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    export()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!hasCompiledIcon)
            }
        }
    }

    private func compile() async {
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

    private func export() {
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

        // Look up the view factory symbol once before the export loop.
        guard let handle = dlopen(dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            exportMessage = .error("Could not load the compiled icon. Try building again.")
            return
        }
        guard let sym = dlsym(handle, "_quickIconsMakeView") else {
            dlclose(handle)
            exportMessage = .error("Could not load the compiled icon. Try building again.")
            return
        }

        typealias MakeViewFn = @convention(c) (Double) -> UnsafeMutableRawPointer
        let makeView = unsafeBitCast(sym, to: MakeViewFn.self)

        let viewFactory: (CGFloat) -> AnyView = { size in
            let opaquePtr = makeView(Double(size))
            let obj = Unmanaged<AnyObject>.fromOpaque(opaquePtr).takeRetainedValue()
            return (obj as? AnyView) ?? AnyView(Color.clear.frame(width: size, height: size))
        }

        do {
            let destination = try exporter.export(viewFactory: viewFactory, name: "AppIcon", to: baseURL)
            dlclose(handle)
            exportMessage = .success(destination.path)
        } catch {
            dlclose(handle)
            exportMessage = .error(error.localizedDescription)
        }
    }
}

enum ExportMessage: Equatable {
    case success(String)
    case error(String)
}

#Preview {
    EditorView()
}
