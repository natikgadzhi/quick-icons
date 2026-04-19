import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String

    var body: some View {
        STTextViewRepresentable(text: $sourceCode)
            .frame(minWidth: 420)
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
