import AppKit
import STPluginNeon

// MARK: - Xcode Default Color Theme

/// A Plugin-Neon `Theme` that mirrors Xcode's stock "Default (Light)" and
/// "Default (Dark)" syntax color schemes.
///
/// Colors are constructed with `NSColor(name:dynamicProvider:)` so a single
/// `Theme` value resolves correctly for both appearances — no restart required.
extension Theme {

    /// Xcode-style light/dark syntax theme.
    static let xcode: Theme = Theme(
        colors: .xcode,
        fonts: .xcode
    )
}

extension Theme.Colors {

    /// Dynamic colors keyed to Xcode's canonical token palette.
    static let xcode: Theme.Colors = {
        // Shared dynamic color values (reused across multiple tokens)
        let plain    = NSColor.xcodeToken(light: 0x000000, dark: 0xFFFFFF)
        let keyword  = NSColor.xcodeToken(light: 0xAD3DA4, dark: 0xFF7AB2)  // #AD3DA4 / #FF7AB2
        let type_    = NSColor.xcodeToken(light: 0x703DAF, dark: 0xD9B9FF)  // #703DAF / #D9B9FF
        let string   = NSColor.xcodeToken(light: 0xD12F1B, dark: 0xFF8170)  // #D12F1B / #FF8170
        let number   = NSColor.xcodeToken(light: 0x272AD8, dark: 0xD9C97C)  // #272AD8 / #D9C97C
        let comment  = NSColor.xcodeToken(light: 0x707F8C, dark: 0x7F8C98)  // #707F8C / #7F8C98

        let colors: [String: NSColor] = [
            "plain":               plain,
            "keyword":             keyword,
            "keyword.function":    keyword,
            "keyword.return":      keyword,
            "include":             keyword,
            "type":                type_,
            "constructor":         type_,
            "string":              string,
            "text.literal":        string,
            "number":              number,
            "boolean":             number,
            "comment":             comment,
            "variable":            plain,
            "variable.builtin":    plain,
            "parameter":           plain,
            "function.call":       plain,
            "method":              plain,
            "operator":            plain,
            "punctuation.special": plain,
            "text.title":          keyword,
        ]
        return Theme.Colors(colors: colors)
    }()
}

extension Theme.Fonts {

    /// Font weights that mirror Xcode's keyword/type emphasis.
    static let xcode: Theme.Fonts = {
        let regular = NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        let medium  = NSFont.monospacedSystemFont(ofSize: 0, weight: .medium)
        let fonts: [String: NSFont] = [
            "plain":               regular,
            "boolean":             regular,
            "comment":             regular,
            "constructor":         regular,
            "function.call":       regular,
            "include":             medium,
            "keyword":             medium,
            "keyword.function":    medium,
            "keyword.return":      medium,
            "method":              regular,
            "number":              regular,
            "operator":            regular,
            "parameter":           regular,
            "punctuation.special": regular,
            "string":              regular,
            "text.literal":        regular,
            "text.title":          medium,
            "type":                regular,
            "variable.builtin":    regular,
            "variable":            regular,
        ]
        return Theme.Fonts(fonts: fonts)
    }()
}

// MARK: - Dynamic color helper

private extension NSColor {

    /// Returns a dynamic `NSColor` that resolves to `light` in light appearances
    /// and `dark` in dark appearances.  Uses `NSColor(name:dynamicProvider:)` so
    /// the system re-queries the provider whenever the effective appearance changes.
    ///
    /// - Parameters:
    ///   - light: 24-bit RGB hex value for light appearance (e.g. `0xAD3DA4`)
    ///   - dark:  24-bit RGB hex value for dark appearance  (e.g. `0xFF7AB2`)
    static func xcodeToken(light lightRGB: Int, dark darkRGB: Int) -> NSColor {
        let lightColor = NSColor(rgb: lightRGB)
        let darkColor  = NSColor(rgb: darkRGB)

        return NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua: return darkColor
            default:        return lightColor
            }
        }
    }

    /// Initializes a color from a 24-bit RGB integer in sRGB color space.
    convenience init(rgb: Int) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8)  & 0xFF) / 255.0
        let b = CGFloat(rgb         & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
