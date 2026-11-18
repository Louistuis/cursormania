import SwiftUI

/// Design tokens. The look borrows a desktop-as-canvas language: an off-white
/// dot-grid page, tight lowercase type, glossy pill buttons, little Mac windows.
enum DS {
    static let canvas = Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let sub = Color(red: 0.45, green: 0.45, blue: 0.47)
    static let faint = Color(red: 0.62, green: 0.62, blue: 0.64)
    static let hairline = Color.black.opacity(0.1)
    static let link = Color(red: 0.13, green: 0.42, blue: 0.98)
    static let aquaBorder = Color(red: 34 / 255, green: 24 / 255, blue: 152 / 255)

    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let softSpring = Animation.spring(response: 0.5, dampingFraction: 0.86)

    static let aqua = LinearGradient(stops: [
        .init(color: Color(red: 237 / 255, green: 244 / 255, blue: 1), location: 0),
        .init(color: Color(red: 214 / 255, green: 231 / 255, blue: 1), location: 0.18),
        .init(color: Color(red: 162 / 255, green: 199 / 255, blue: 1), location: 0.5),
        .init(color: Color(red: 153 / 255, green: 203 / 255, blue: 248 / 255), location: 0.8),
        .init(color: Color(red: 162 / 255, green: 210 / 255, blue: 247 / 255), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    static let pearl = LinearGradient(stops: [
        .init(color: Color(white: 0.985), location: 0),
        .init(color: Color(white: 0.93), location: 0.42),
        .init(color: Color(white: 0.895), location: 1),
    ], startPoint: .top, endPoint: .bottom)
}

extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

extension View {
    /// Tight tracking that scales with the size, like the reference type.
    func tight(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        font(.ui(size, weight)).tracking(-size * 0.03)
    }
}

/// The dotted page background.
struct DotGrid: View {
    var spacing: CGFloat = 18
    var color: Color = .black.opacity(0.13)
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Glossy pill buttons: blue for the main action, pearl for the rest.
struct PillStyle: ButtonStyle {
    var primary = true
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tight(compact ? 13 : 15, .medium)
            .foregroundStyle(DS.ink)
            .padding(.horizontal, compact ? 13 : 18)
            .padding(.vertical, compact ? 6 : 9)
            .background(Capsule().fill(primary ? DS.aqua : DS.pearl))
            .overlay(Capsule().strokeBorder(primary ? DS.aquaBorder.opacity(0.85) : Color(white: 0.38), lineWidth: 0.7))
            .overlay(alignment: .top) {
                // The wet highlight across the top half.
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .padding(.horizontal, 6).padding(.top, 1.5)
                    .frame(height: compact ? 11 : 15)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.12), radius: configuration.isPressed ? 6 : 12, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(DS.spring, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A plain text button that underlines on hover, like a menu bar link.
struct LinkStyle: ButtonStyle {
    var active = false
    var color: Color = DS.ink
    func makeBody(configuration: Configuration) -> some View {
        LinkLabel(label: configuration.label, active: active, pressed: configuration.isPressed, color: color)
    }
    private struct LinkLabel<L: View>: View {
        let label: L; let active: Bool; let pressed: Bool; let color: Color
        @State private var hover = false
        var body: some View {
            label
                .foregroundStyle(active ? DS.ink : (hover ? DS.ink : color))
                .opacity(pressed ? 0.6 : 1)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(active ? 0.075 : (hover ? 0.04 : 0))))
                .animation(DS.spring, value: hover)
                .onHover { hover = $0 }
                .contentShape(Capsule())
        }
    }
}

/// A small Mac window, the frame every preview sits in.
struct MacWindow<Content: View>: View {
    var title: String
    var highlighted = false
    var dark = false
    var radius: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(highlighted ? [Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)][i] : Color.black.opacity(dark ? 0.0 : 0.12))
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                            .frame(width: 9, height: 9)
                    }
                    Spacer()
                }
                Text(title).tight(11, .medium).foregroundStyle(dark ? Color.white.opacity(0.55) : DS.sub).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(dark ? Color(white: 0.11) : Color(white: 0.975))
            Rectangle().fill(dark ? Color.white.opacity(0.06) : DS.hairline).frame(height: 0.5)
            content
        }
        .background(dark ? Color(white: 0.07) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(highlighted ? DS.link.opacity(0.9) : Color.black.opacity(0.13), lineWidth: highlighted ? 1.5 : 0.7))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
    }
}

/// A tiny label in the corner of things.
struct Chip: View {
    var text: String
    var tint: Color = DS.sub
    var body: some View {
        Text(text).tight(10.5, .medium).foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 2.5)
            .background(Capsule().fill(tint.opacity(0.1)))
    }
}
