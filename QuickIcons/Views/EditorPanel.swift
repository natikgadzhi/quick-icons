import SwiftUI

struct EditorPanel: View {
    @Binding var sourceCode: String
    var showsInvisibles: Bool = false
    var fontSize: CGFloat = 13
    /// Forwarded to ``STTextViewRepresentable`` — fires when the sourcekitd
    /// diagnostics pipeline becomes (un)available.
    var onDiagnosticsAvailabilityChange: ((Bool) -> Void)? = nil
    /// Forwarded to ``STTextViewRepresentable`` — handles `.swift` files dropped
    /// onto the editor. Returns whether the drop was handled.
    var onDropFiles: (([URL]) -> Bool)? = nil

    var body: some View {
        STTextViewRepresentable(
            text: $sourceCode,
            showsInvisibles: showsInvisibles,
            fontSize: fontSize,
            onDiagnosticsAvailabilityChange: onDiagnosticsAvailabilityChange,
            onDropFiles: onDropFiles
        )
    }
}

#Preview {
    EditorPanel(sourceCode: .constant("// Swift source code"))
        .frame(width: 500, height: 400)
}
