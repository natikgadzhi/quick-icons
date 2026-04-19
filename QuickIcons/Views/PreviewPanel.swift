import AppKit
import SwiftUI

struct PreviewPanel: View {
    var image: NSImage?
    var errorMessage: String?
    var isCompiling: Bool = false

    var body: some View {
        if let errorMessage {
            errorView(message: errorMessage)
        } else if let image {
            imageView(image: image)
        } else {
            emptyView()
        }
    }

    @ViewBuilder
    private func imageView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .padding()
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
}

#Preview("Empty") {
    PreviewPanel(image: nil)
        .frame(width: 400, height: 400)
}

#Preview("Error") {
    PreviewPanel(image: nil, errorMessage: "Error on line 14: use of unresolved identifier 'foo'")
        .frame(width: 400, height: 400)
}

#Preview("Compiling") {
    PreviewPanel(image: nil, errorMessage: nil, isCompiling: true)
        .frame(width: 400, height: 400)
}
