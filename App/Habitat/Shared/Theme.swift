import SwiftUI
import UIKit

extension Color {
    /// `#RRGGBB` (the `#` is optional). An invalid string gives grey.
    init(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A colour that switches between two hex values with the appearance.
    fileprivate init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

enum Theme {
    /// The 8 colours a habit can have (`#RRGGBB`), in picker order. Habits store the hex string.
    static let habitPalette: [String] = [
        "#E5484D", // red
        "#F76B15", // orange
        "#C99700", // yellow
        "#30A46C", // green
        "#12A594", // teal
        "#3E63DD", // blue
        "#8E4EC6", // purple
        "#D6409F" // pink
    ]

    static let defaultHabitColorHex = habitPalette[5]

    /// Weekly goal status colours. Use as text/icon colour on the system background
    /// (contrast at least 4.5:1 in light and dark); pair with a symbol or label,
    /// never colour alone.
    enum Status {
        static let met = Color(light: "#17663F", dark: "#5FD38D")
        static let failed = Color(light: "#B42318", dark: "#FF8A80")
        static let inProgress = Color(light: "#8A5A00", dark: "#F5C451")
    }

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 12
    }

    /// Minimum tappable size (HIG).
    static let minTapTarget: CGFloat = 44
}
