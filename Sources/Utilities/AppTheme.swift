import SwiftUI

/// MuxCore design tokens aligned with `media-ui-app/src/index.css`.
enum AppTheme {
    struct Palette: Equatable {
        var background: Color
        var surface: Color
        var surfaceElevated: Color
        var textPrimary: Color
        var textSecondary: Color
        var accent: Color
        var accentHover: Color
        var playerScrim: Color
        var playerChip: Color

        static let dark = Palette(
            background: Color(hex: 0x0b0c0f),
            surface: Color(hex: 0x15161b),
            surfaceElevated: Color(hex: 0x1c1e26),
            textPrimary: Color(hex: 0xf5f5f7),
            textSecondary: Color(hex: 0xa1a1aa),
            accent: Color(hex: 0x3db8a8),
            accentHover: Color(hex: 0x56d0c0),
            playerScrim: Color.black.opacity(0.55),
            playerChip: Color.white.opacity(0.12)
        )

        static let light = Palette(
            background: Color(hex: 0xf4f4f6),
            surface: Color(hex: 0xffffff),
            surfaceElevated: Color(hex: 0xeceef2),
            textPrimary: Color(hex: 0x14151a),
            textSecondary: Color(hex: 0x5c5f6a),
            accent: Color(hex: 0x3db8a8),
            accentHover: Color(hex: 0x56d0c0),
            playerScrim: Color.black.opacity(0.45),
            playerChip: Color.white.opacity(0.18)
        )
    }

    static func palette(colorScheme: ColorScheme) -> Palette {
        colorScheme == .dark ? .dark : .light
    }

    static func palette(theme: DisplayPrefs.Theme, colorScheme: ColorScheme) -> Palette {
        switch theme {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return palette(colorScheme: colorScheme)
        }
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.Palette.dark
}

extension EnvironmentValues {
    var muxTheme: AppTheme.Palette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
