import SwiftUI
import UIKit

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

/// Free, built-in backgrounds the user can pick in Settings, independent of the
/// accent color scheme above. Drawn in code (no bundled images), so they always
/// tint to match whichever WorkspaceTheme accent is active.
enum WallpaperPreset: String, CaseIterable, Identifiable, Codable {
    case none, tint, linen, grid

    var id: String { rawValue }

    func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.none, .ru): return "Без обоев"
        case (.none, .en): return "No wallpaper"
        case (.tint, .ru): return "Заливка цветом"
        case (.tint, .en): return "Color wash"
        case (.linen, .ru): return "Лён"
        case (.linen, .en): return "Linen"
        case (.grid, .ru): return "Сетка"
        case (.grid, .en): return "Grid"
        }
    }

    @ViewBuilder
    func background(accent: Color) -> some View {
        switch self {
        case .none:
            Color(.systemGroupedBackground)
        case .tint:
            accent.opacity(0.08)
        case .linen:
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(accent.opacity(0.05)))
                var y: CGFloat = -size.height
                while y < size.width + size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + size.width))
                    context.stroke(path, with: .color(accent.opacity(0.10)), lineWidth: 1)
                    y += 14
                }
            }
        case .grid:
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(accent.opacity(0.04)))
                var x: CGFloat = 0
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(accent.opacity(0.10)), lineWidth: 1)
                    x += 24
                }
                var y: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(accent.opacity(0.10)), lineWidth: 1)
                    y += 24
                }
            }
        }
    }
}

/// Shared "pill" button look (solid fill + light stroke + soft shadow) used for
/// every capsule action button in the org chart. The stroke and shadow keep the
/// button visibly separated from the page no matter which wallpaper or theme
/// accent is behind it, instead of relying on fill-color contrast alone.
struct PillButtonStyle: ViewModifier {
    var color: Color
    var textColor: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

extension View {
    func pillButton(_ color: Color) -> some View {
        modifier(PillButtonStyle(color: color))
    }
}

extension UIImage {
    /// Downscales to at most `maxDimension` on the longer side, used before
    /// storing a user-picked wallpaper photo so it stays a reasonable size.
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
