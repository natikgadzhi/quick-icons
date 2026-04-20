import AppKit
import SwiftUI

struct PreviewPanel: View {
    var image: NSImage?
    var errorMessage: String?
    var isCompiling: Bool = false
    @Binding var exportMessage: ExportMessage?

    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Invisible baseline fixes the panel's intrinsic size so switching
            // between placeholder, compiling, image, and error states never
            // causes the enclosing HSplitView to relayout.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let errorMessage {
                errorView(message: errorMessage)
            } else if let image {
                imageView(image: image)
            } else {
                emptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let exportMessage {
                toastView(message: exportMessage)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: exportMessage) { _, newValue in
            dismissTask?.cancel()
            guard newValue != nil else { return }
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    exportMessage = nil
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: exportMessage)
    }

    @ViewBuilder
    private func imageView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .opacity(isCompiling ? 0.4 : 1.0)
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isCompiling {
                    ProgressView()
                }
            }
    }

    @ViewBuilder
    private func emptyView() -> some View {
        VStack(spacing: 12) {
            if isCompiling {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Compiling…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Compile to preview")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func toastView(message: ExportMessage) -> some View {
        HStack(spacing: 8) {
            switch message {
            case .success(let path):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Exported to \(path)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .error(let text):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Empty") {
    PreviewPanel(image: nil, exportMessage: .constant(nil))
        .frame(width: 400, height: 400)
}

#Preview("Error") {
    PreviewPanel(image: nil, errorMessage: "Error on line 14: use of unresolved identifier 'foo'", exportMessage: .constant(nil))
        .frame(width: 400, height: 400)
}

#Preview("Compiling") {
    PreviewPanel(image: nil, errorMessage: nil, isCompiling: true, exportMessage: .constant(nil))
        .frame(width: 400, height: 400)
}

#Preview("Export Success Toast") {
    PreviewPanel(image: nil, exportMessage: .constant(.success("/Users/me/Desktop/AppIcon.appiconset")))
        .frame(width: 400, height: 400)
}

#Preview("Export Error Toast") {
    PreviewPanel(image: nil, exportMessage: .constant(.error("Failed to write to /tmp: permission denied")))
        .frame(width: 400, height: 400)
}
