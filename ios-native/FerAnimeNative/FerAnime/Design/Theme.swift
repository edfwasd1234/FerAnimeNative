import SwiftUI

enum Theme {
    // Core backgrounds
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let backgroundElevated = Color(red: 0.09, green: 0.09, blue: 0.13)

    // Glass surfaces
    static let panel = Color.white.opacity(0.08)
    static let panelMid = Color.white.opacity(0.11)
    static let panelStrong = Color.white.opacity(0.15)

    // Strokes
    static let stroke = Color.white.opacity(0.12)
    static let strokeBright = Color.white.opacity(0.28)

    // Text hierarchy
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.68)
    static let tertiary = Color.white.opacity(0.42)

    // Accents
    static let accent = Color(red: 1.0, green: 0.38, blue: 0.16)
    static let cyan = Color(red: 0.35, green: 0.78, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.38, blue: 0.62)
    static let violet = Color(red: 0.56, green: 0.48, blue: 1.0)
    static let appleBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let aurora = appleBlue
    static let emerald = Color(red: 0.18, green: 0.82, blue: 0.50)
}
