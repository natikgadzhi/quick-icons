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
    ///
    /// Covers every capture emitted by
    /// `STTextView-Plugin-Neon/Sources/TreeSitterSwiftQueries/highlights.scm` (28
    /// distinct scopes). Light/dark hex pairs mirror Xcode's stock
    /// "Default (Light)" and "Default (Dark)" themes.
    static let xcode: Theme.Colors = {
        // Shared dynamic color values (reused across multiple tokens).
        let plain       = NSColor.xcodeToken(light: 0x000000, dark: 0xFFFFFF)
        let keyword     = NSColor.xcodeToken(light: 0xAD3DA4, dark: 0xFF7AB2)  // magenta
        let type_       = NSColor.xcodeToken(light: 0x703DAF, dark: 0xD9B9FF)  // purple
        let string      = NSColor.xcodeToken(light: 0xD12F1B, dark: 0xFF8170)  // red/coral
        let number      = NSColor.xcodeToken(light: 0x272AD8, dark: 0xD9C97C)  // blue/tan
        let comment     = NSColor.xcodeToken(light: 0x707F8C, dark: 0x7F8C98)  // gray
        let functionCall = NSColor.xcodeToken(light: 0x272AD8, dark: 0x41A1C0) // project function blue
        let property    = NSColor.xcodeToken(light: 0x326D74, dark: 0x67B7A4)  // instance property teal
        let macro       = NSColor.xcodeToken(light: 0x804FB8, dark: 0xFFA14F)  // attribute/macro
        let regex       = NSColor.xcodeToken(light: 0x4C4C6A, dark: 0xB89EF8)  // regex literal

        let colors: [String: NSColor] = [
            // Baseline / fallback
            "plain":                 plain,

            // Keywords and keyword-flavored scopes
            "keyword":               keyword,
            "keyword.function":      keyword,
            "keyword.return":        keyword,
            "keyword.operator":      keyword,
            "conditional":           keyword,
            "repeat":                keyword,
            "include":               keyword,
            "variable.builtin":      keyword,  // self, super, nil — Xcode bolds in magenta

            // Types
            "type":                  type_,
            "constructor":           type_,

            // Functions / methods / macros
            "method":                functionCall,
            "function.call":         functionCall,
            "function.macro":        macro,

            // Identifiers
            "variable":              plain,
            "parameter":             plain,
            "property":              property,
            "label":                 plain,

            // Literals
            "string":                string,
            "string.regex":          regex,
            "text.literal":          string,
            "number":                number,
            "float":                 number,
            "boolean":               number,

            // Comments
            "comment":               comment,
            "spell":                 comment,

            // Punctuation / operators
            "operator":              plain,
            "punctuation.bracket":   plain,
            "punctuation.delimiter": plain,
            "punctuation.special":   plain,

            // Markdown-ish (kept from previous theme, no-op for Swift)
            "text.title":            keyword,
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
            "plain":                 regular,

            // Keyword-flavored scopes render in medium weight, matching Xcode.
            "keyword":               medium,
            "keyword.function":      medium,
            "keyword.return":        medium,
            "keyword.operator":      medium,
            "conditional":           medium,
            "repeat":                medium,
            "include":               medium,
            "variable.builtin":      medium,
            "text.title":            medium,

            // Regular-weight scopes
            "boolean":               regular,
            "comment":               regular,
            "spell":                 regular,
            "constructor":           regular,
            "function.call":         regular,
            "function.macro":        regular,
            "method":                regular,
            "number":                regular,
            "float":                 regular,
            "operator":              regular,
            "parameter":             regular,
            "property":              regular,
            "label":                 regular,
            "punctuation.bracket":   regular,
            "punctuation.delimiter": regular,
            "punctuation.special":   regular,
            "string":                regular,
            "string.regex":          regular,
            "text.literal":          regular,
            "type":                  regular,
            "variable":              regular,
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
