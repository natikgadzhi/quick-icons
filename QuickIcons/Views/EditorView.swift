import AppKit
import SwiftUI

/// Root editor scene: a split view with source on the left and preview on the
/// right. All compile/export state lives on ``EditorViewModel``; this view is
/// purely structural and forwards toolbar / menu actions into the model.
struct EditorView: View {
    @State private var model = EditorViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var model = model

        GeometryReader { proxy in
            HSplitView {
                EditorPanel(
                    sourceCode: $model.sourceCode,
                    showsInvisibles: model.showsInvisibles,
                    fontSize: model.fontSize,
                    onDiagnosticsAvailabilityChange: { unavailable in
                        model.diagnosticsUnavailable = unavailable
                    },
                    onDropFiles: { model.openDroppedFiles($0) }
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
                    exportMessage: $model.exportMessage,
                    previewMode: $model.previewMode
                )
                .frame(
                    minWidth: 300,
                    idealWidth: proxy.size.width / 4,
                    maxWidth: max(proxy.size.width * 0.35, 300)
                )
            }
        }
        .frame(minWidth: 1080, minHeight: 500)
        // Window-wide drop target so a .swift file can be dropped anywhere in the
        // app. Drops over the editor itself are handled by DropEnabledTextView;
        // this covers the preview pane and surrounding chrome.
        .dropDestination(for: URL.self) { urls, _ in
            model.openDroppedFiles(urls)
        } isTargeted: {
            isDropTargeted = $0
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: model.sourceCode) { model.sourceCodeChanged() }
        .onChange(of: model.previewMode) { model.renderPreview() }
        .focusedSceneValue(\.editorViewModel, model)
        .toolbar {
            if model.diagnosticsUnavailable {
                ToolbarItem(placement: .status) {
                    Label("Diagnostics unavailable", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("SourceKit returned an error for the last diagnostics request — inline errors may be out of date.")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.compile() }
                } label: {
                    Label(
                        model.isCompiling ? "Building…" : "Build",
                        systemImage: "play.fill"
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
