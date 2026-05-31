//
//  IconPreviewMode.swift
//  QuickIcons
//

/// Which framing the icon preview renders.
///
/// macOS app icons are exported with Apple's rounded body and a transparent margin baked
/// in, whereas iOS/iPad icons are exported full-bleed (the OS rounds them at display time).
/// The preview lets the user switch between those two looks.
enum IconPreviewMode: String, CaseIterable, Identifiable {
    /// Apple's macOS framing: rounded body + transparent margin. Matches the macOS export.
    case macOS
    /// The raw full-bleed artwork, as the iOS/iPad variants are exported.
    case original

    var id: Self { self }

    /// Title shown in the preview's mode picker.
    var title: String {
        switch self {
        case .macOS: "macOS"
        case .original: "Original"
        }
    }
}
