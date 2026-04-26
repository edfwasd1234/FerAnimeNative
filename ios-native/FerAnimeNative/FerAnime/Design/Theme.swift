import SwiftUI

enum Theme {
    static let background = Color(red: 0.025, green: 0.025, blue: 0.030)
    static let panel = Color.white.opacity(0.09)
    static let panelStrong = Color.white.opacity(0.15)
    static let stroke = Color.white.opacity(0.18)
    static let strokeBright = Color.white.opacity(0.34)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.70)
    static let tertiary = Color.white.opacity(0.48)
    static let accent = Color(red: 1.0, green: 0.38, blue: 0.16)
    static let cyan = Color(red: 0.18, green: 0.78, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.22, blue: 0.55)
    static let violet = Color(red: 0.52, green: 0.38, blue: 1.0)

    static let aurora = LinearGradient(
        colors: [accent, pink, violet, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

