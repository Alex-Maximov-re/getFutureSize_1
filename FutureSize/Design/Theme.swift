import SwiftUI
import UIKit

enum Theme {
    static let paper = adaptive(light: 0xF3EEE6, dark: 0x101614)
    static let card = adaptive(light: 0xFFFCF7, dark: 0x1B2420)
    static let ink = adaptive(light: 0x1C2421, dark: 0xF4F0E8)
    static let secondary = adaptive(light: 0x5C675F, dark: 0xC5D0C8)
    static let spruce = adaptive(light: 0x1F6B54, dark: 0x8ED7B8)
    static let amber = adaptive(light: 0xA15C12, dark: 0xE6B15E)
    static let coral = adaptive(light: 0x9C3B32, dark: 0xF0A8A0)
    static let hairline = adaptive(light: 0xE3DCD0, dark: 0x2C3933)
    static let button = Color(red: 23 / 255, green: 79 / 255, blue: 62 / 255)
    static let buttonText = Color.white

    static let avatarPalette: [Color] = [
        Color(hex: 0x174F3E),
        Color(hex: 0x6E4636),
        Color(hex: 0x2C4760),
        Color(hex: 0x6E4318),
        Color(hex: 0x3C5640),
    ]

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

extension View {
    func paperScreen() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}
