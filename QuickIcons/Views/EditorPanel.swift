import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String
    var showsInvisibles: Bool = false
    var fontSize: CGFloat = 13

    var body: some View {
        STTextViewRepresentable(text: $sourceCode, showsInvisibles: showsInvisibles, fontSize: fontSize)
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
