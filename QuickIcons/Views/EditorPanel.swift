import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String

    var body: some View {
        TextEditor(text: $sourceCode)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 420)
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
