import SwiftUI

enum ThemeResolver {
    static func colorScheme(for theme: DisplayPrefs.Theme) -> ColorScheme? {
        switch theme {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
