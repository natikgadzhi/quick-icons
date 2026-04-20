import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String
    var showsInvisibles: Bool = false
    var fontSize: CGFloat = 13
    /// Forwarded to ``STTextViewRepresentable`` — fires when the sourcekitd
    /// diagnostics pipeline becomes (un)available.
    var onDiagnosticsAvailabilityChange: ((Bool) -> Void)? = nil

    var body: some View {
        STTextViewRepresentable(
            text: $sourceCode,
            showsInvisibles: showsInvisibles,
            fontSize: fontSize,
            onDiagnosticsAvailabilityChange: onDiagnosticsAvailabilityChange
        )
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
