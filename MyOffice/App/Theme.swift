import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum WorkspaceTheme: String, CaseIterable, Identifiable {
    case office, midnight, sage, sunset

    var id: String { rawValue }
    var gated: Bool { self != .office }

    var accent: Color {
        switch self {
        case .office: return Color(hex: 0x1F3A5C)
        case .midnight: return Color(hex: 0x22314A)
        case .sage: return Color(hex: 0x3C5B48)
        case .sunset: return Color(hex: 0x6B3A3A)
        }
    }

    func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.office, .ru): return "Офис"
        case (.office, .en): return "Office"
        case (.midnight, .ru): return "Полночь"
        case (.midnight, .en): return "Midnight"
        case (.sage, .ru): return "Шалфей"
        case (.sage, .en): return "Sage"
        case (.sunset, .ru): return "Закат"
        case (.sunset, .en): return "Sunset"
        }
    }
}

// Fixed accents for the two demo departments, independent of the active
// workspace theme — same idea as the HTML prototype's per-branch border colors.
enum DeptAccent {
    static let sales = Color(hex: 0x2E7D6B)
    static let tech = Color(hex: 0x5B4B8A)
    static let ceo = Color(hex: 0xC99A3D)
}
