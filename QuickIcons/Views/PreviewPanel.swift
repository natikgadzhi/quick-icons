import AppKit
import SwiftUI

struct PreviewPanel: View {
    var image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding()
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Compile to preview")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    PreviewPanel(image: nil)
        .frame(width: 400, height: 400)
}
