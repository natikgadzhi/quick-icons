import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String
    var showsInvisibles: Bool = false

    var body: some View {
        STTextViewRepresentable(text: $sourceCode, showsInvisibles: showsInvisibles)
            .frame(minWidth: 420)
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
