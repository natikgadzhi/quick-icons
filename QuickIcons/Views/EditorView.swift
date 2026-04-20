import AppKit
import SwiftUI

/// Root editor scene: a split view with source on the left and preview on the
/// right. All compile/export state lives on ``EditorViewModel``; this view is
/// purely structural and forwards toolbar / menu actions into the model.
struct EditorView: View {
    @State private var model = EditorViewModel()

    var body: some View {
        @Bindable var model = model

        GeometryReader { proxy in
            HSplitView {
                EditorPanel(
                    sourceCode: $model.sourceCode,
                    showsInvisibles: model.showsInvisibles,
                    fontSize: model.fontSize
                )
                .frame(
                    minWidth: 420,
                    idealWidth: proxy.size.width * 2 / 3,
                    maxWidth: .infinity
                )
                PreviewPanel(
                    image: model.compiledImage,
                    errorMessage: model.compileError,
                    isCompiling: model.isCompiling,
                    exportMessage: $model.exportMessage
                )
                .frame(
                    minWidth: 300,
                    idealWidth: proxy.size.width / 4,
                    maxWidth: max(proxy.size.width * 0.35, 300)
                )
            }
        }
        .frame(minWidth: 1080, minHeight: 500)
        .onChange(of: model.sourceCode) { model.sourceCodeChanged() }
        .focusedSceneValue(\.editorViewModel, model)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.compile() }
                } label: {
                    Label(
                        model.isCompiling ? "Building…" : "Build",
                        systemImage: model.isCompiling ? "hammer" : "hammer.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isCompiling)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.export()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!model.hasCompiledIcon)
            }
        }
    }
}

#Preview {
    EditorView()
}
