import SwiftUI

/// "make your own": every knob of the painter, with the full set of states
/// redrawing live on the right.
struct BuilderView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State var theme: CursorTheme

    static func blank(from base: CursorTheme?) -> CursorTheme {
        var t = base ?? Catalog.themes[0]
        let isOwn = t.category == .custom
        t.id = isOwn ? t.id : "custom.\(UUID().uuidString.prefix(8).lowercased())"
        t.name = isOwn ? t.name : (base == nil ? "my cursor" : "\(t.name.lowercased()) remix")
        t.category = .custom
        return t
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("make your own").tight(24, .medium)
                    TextField("name", text: $theme.name).textFieldStyle(.roundedBorder).tight(13)

                    group("shape") {
                        Picker("", selection: $theme.style.shape) {
                            ForEach(ArrowShape.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }

                    group("fill") {
                        HStack {
                            ForEach(theme.style.fill.indices, id: \.self) { i in
                                ColorPicker("", selection: rgba($theme.style.fill[i]), supportsOpacity: true).labelsHidden()
                            }
                            Spacer()
                            Button { if theme.style.fill.count < 4 { theme.style.fill.append(theme.style.fill.last!.hueShifted(0.12)) } } label: { Image(systemName: "plus") }
                                .buttonStyle(PillStyle(primary: false, compact: true))
                                .disabled(theme.style.fill.count >= 4)
                            Button { if theme.style.fill.count > 1 { theme.style.fill.removeLast() } } label: { Image(systemName: "minus") }
                                .buttonStyle(PillStyle(primary: false, compact: true))
                                .disabled(theme.style.fill.count <= 1)
                        }
                        if theme.style.fill.count > 1 {
                            slider("direction", $theme.style.angle, 0...360, "%.0f°")
                        }
                    }

                    group("outline") {
                        HStack {
                            ColorPicker("", selection: rgba($theme.style.outline), supportsOpacity: true).labelsHidden()
                            slider("width", $theme.style.outlineWidth, 0...2.5, "%.1f")
                        }
                    }

                    group("light") {
                        Toggle("glow", isOn: Binding(get: { theme.style.glow != nil },
                                                     set: { theme.style.glow = $0 ? (theme.style.fill.first ?? .white).alpha(0.95) : nil }))
                        if theme.style.glow != nil {
                            HStack {
                                ColorPicker("", selection: Binding(get: { (theme.style.glow ?? .white).color },
                                                                   set: { theme.style.glow = RGBA(NSColor($0)) }), supportsOpacity: true).labelsHidden()
                                slider("radius", $theme.style.glowRadius, 1...10, "%.0f")
                            }
                        }
                        slider("shadow", $theme.style.shadow, 0...0.8, "%.2f")
                        Toggle("glass shine", isOn: $theme.style.gloss)
                    }

                    group("motion") {
                        Picker("", selection: $theme.style.motion) {
                            ForEach(Motion.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }

                    group("badges & spinner") {
                        ColorPicker("accent", selection: rgba($theme.style.accent))
                    }

                    group("base size") {
                        slider("scale", $theme.style.scale, 0.8...2.2, "%.2gx")
                    }
                }
                .tint(DS.link)
                .padding(22)
            }
            .frame(width: 330)
            .background(Color.white.opacity(0.6))

            Rectangle().fill(DS.hairline).frame(width: 0.5)

            VStack(alignment: .leading, spacing: 16) {
                MacWindow(title: "\(theme.name.lowercased()).cape", highlighted: true) {
                    StatesBoard(theme: theme, compact: true)
                }
                Text("hover any state to try it right here.").tight(12).foregroundStyle(DS.sub)
                Spacer()
                HStack {
                    Button("cancel") { dismiss() }.buttonStyle(PillStyle(primary: false))
                    Spacer()
                    Button("save & wear") {
                        model.saveCustom(theme)
                        dismiss()
                    }
                    .buttonStyle(PillStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 960, height: 640)
        .background(ZStack { DS.canvas; DotGrid() })
        .environment(\.colorScheme, .light)
    }

    func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).tight(12, .medium).foregroundStyle(DS.faint)
            c()
        }
        .tight(13)
    }

    func slider(_ label: String, _ v: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String) -> some View {
        HStack(spacing: 10) {
            Text(label).tight(12.5).foregroundStyle(DS.sub).frame(width: 52, alignment: .leading)
            Slider(value: v, in: range).controlSize(.small)
            Text(String(format: fmt, v.wrappedValue)).tight(11.5).foregroundStyle(DS.faint).monospacedDigit().frame(width: 38, alignment: .trailing)
        }
    }

    func rgba(_ b: Binding<RGBA>) -> Binding<Color> {
        Binding(get: { b.wrappedValue.color }, set: { b.wrappedValue = RGBA(NSColor($0)) })
    }
}
