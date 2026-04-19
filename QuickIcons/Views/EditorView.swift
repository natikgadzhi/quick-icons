import AppKit
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

    private let compiler = SwiftCompilerService()
    private let previewer = IconPreviewService()

    var body: some View {
        HSplitView {
            EditorPanel(sourceCode: $sourceCode)
            PreviewPanel(
                image: compiledImage,
                errorMessage: compileError,
                isCompiling: isCompiling
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isCompiling ? "Compiling…" : "Compile") {
                    Task { await compile() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCompiling)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    // TODO: wire up export action in a later task
                }
            }
        }
    }

    private func compile() async {
        isCompiling = true
        compiledImage = nil
        compileError = nil

        let result = await compiler.compile(source: sourceCode)

        switch result {
        case .success(let dylibURL):
            compiledImage = previewer.render(dylibURL: dylibURL, size: 400)
            compileError = nil
        case .failure(let diagnostics):
            compiledImage = nil
            if let first = diagnostics.first(where: { $0.severity == .error }) {
                compileError = "Error on line \(first.line): \(first.message)"
            } else if let first = diagnostics.first {
                compileError = "Error on line \(first.line): \(first.message)"
            } else {
                compileError = "Compilation failed with unknown error."
            }
        }

        isCompiling = false
    }
}

#Preview {
    EditorView()
}
