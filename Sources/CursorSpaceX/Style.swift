import AppKit
import SwiftUI

struct RGBA: Codable, Hashable {
    var r: Double, g: Double, b: Double, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(_ hex: UInt32, _ a: Double = 1) {
        r = Double((hex >> 16) & 0xff) / 255; g = Double((hex >> 8) & 0xff) / 255; b = Double(hex & 0xff) / 255; self.a = a
    }
    init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? .black
        r = c.redComponent; g = c.greenComponent; b = c.blueComponent; a = c.alphaComponent
    }

    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var ns: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    var hex: String { String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255)) }

    func alpha(_ x: Double) -> RGBA { RGBA(r, g, b, x) }
    func mix(_ o: RGBA, _ t: Double) -> RGBA { RGBA(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }

    func hueShifted(_ shift: Double) -> RGBA {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, al: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &v, alpha: &al)
        var nh = (h + shift).truncatingRemainder(dividingBy: 1); if nh < 0 { nh += 1 }
        return RGBA(NSColor(hue: nh, saturation: s, brightness: v, alpha: al))
    }

    func brightness(_ f: Double) -> RGBA {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, al: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &v, alpha: &al)
        return RGBA(NSColor(hue: h, saturation: s, brightness: min(1, max(0, v * f)), alpha: al))
    }

    static let black = RGBA(0, 0, 0)
    static let white = RGBA(1, 1, 1)
}

enum ArrowShape: String, Codable, CaseIterable, Identifiable {
    case classic, sleek, dart, dot, ring, pixel
    var id: String { rawValue }
    var isDot: Bool { self == .dot || self == .ring }
    var title: String { rawValue }
}

enum Motion: String, Codable, CaseIterable, Identifiable {
    case none, hue, pulse, shimmer, breathe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "still"
        case .hue: return "rainbow"
        case .pulse: return "pulse"
        case .shimmer: return "shimmer"
        case .breathe: return "breathe"
        }
    }
}

/// Everything that makes a theme look the way it does. Every cursor state is
/// drawn from this, so one style gives a complete, consistent set.
struct CursorStyle: Codable, Hashable {
    var shape: ArrowShape = .classic
    /// One colour is a solid fill; more make a gradient.
    var fill: [RGBA] = [.black]
    /// Gradient direction in degrees, 90 = top to bottom.
    var angle: Double = 90
    var outline: RGBA = .white
    var outlineWidth: Double = 1.3
    var glow: RGBA? = nil
    var glowRadius: Double = 5
    var shadow: Double = 0.38
    var gloss: Bool = false
    var motion: Motion = .none
    var accent: RGBA = RGBA(0x0a84ff)
    var scale: Double = 1
}

enum ThemeCategory: String, Codable, CaseIterable, Identifiable {
    case essentials, pop, gradient, neon, glass, metal, pixel, dots, animated, bold, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .essentials: return "essentials"
        case .pop: return "color pop"
        case .gradient: return "gradients"
        case .neon: return "neon"
        case .glass: return "glass"
        case .metal: return "metal"
        case .pixel: return "pixel"
        case .dots: return "dots"
        case .animated: return "animated"
        case .bold: return "big & bold"
        case .custom: return "made by you"
        }
    }
    var symbol: String {
        switch self {
        case .essentials: return "cursorarrow"
        case .pop: return "paintpalette"
        case .gradient: return "circle.lefthalf.filled"
        case .neon: return "sparkle"
        case .glass: return "drop"
        case .metal: return "seal"
        case .pixel: return "square.grid.3x3"
        case .dots: return "circle.fill"
        case .animated: return "wand.and.stars"
        case .bold: return "textformat.size.larger"
        case .custom: return "paintbrush.pointed"
        }
    }
}

struct CursorTheme: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var category: ThemeCategory
    var style: CursorStyle
}
