import SwiftUI

/// The maker. Everything is a click on something you can see: no sliders unless
/// you open "fine tune". The preview on the left is the real artwork, and you can
/// hover it to feel the cursor before wearing it.
struct CreatePage: View {
    @EnvironmentObject var model: AppModel
    var renderMode = false

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            PreviewColumn()
                .frame(width: 420)
            if renderMode {
                Steps()
            } else {
                ScrollView { Steps().padding(.bottom, 40) }.scrollIndicators(.never)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }
}

// MARK: - Preview

private struct PreviewColumn: View {
    @EnvironmentObject var model: AppModel
    @State private var darkStage = false
    @State private var hover = false

    var style: CursorStyle { model.draft.style }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("make a cursor").tight(30, .medium)
                Text("pick from the steps on the right. it updates as you click.").tight(13.5).foregroundStyle(DS.sub)
            }

            MacWindow(title: "\(model.draft.name.lowercased()).cape", highlighted: true, dark: darkStage) {
                ZStack(alignment: .bottomLeading) {
                    CardLook.backdrop(style, model.draft.category, dark: darkStage)
                    TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animates)) { ctx in
                        stage(frame: frame(ctx.date), spinner: frame(ctx.date, .wait))
                    }
                    HStack(spacing: 4) {
                        bgChip(false, "sun.max"); bgChip(true, "moon")
                        Spacer()
                        Text(hover ? "this is your cursor now" : "hover to try it").tight(11.5, .medium)
                            .foregroundStyle(darkStage ? Color.white.opacity(0.6) : DS.sub)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .glassEffect(.regular, in: Capsule())
                    }
                    .padding(10)
                }
                .frame(height: 300)
                .onHover { hover = $0 }
                .pointerStyle(.image(Image(nsImage: PreviewCache.shared.image(style: style, .arrow)), hotSpot: PreviewCache.shared.hotspot(style: style, .arrow)))
            }
            .animation(DS.softSpring, value: darkStage)

            HStack(spacing: 8) {
                Image(systemName: "pencil").font(.ui(12, .medium)).foregroundStyle(DS.sub)
                TextField("name it", text: $model.draft.name).textFieldStyle(.plain).tight(15, .medium)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.hairline, lineWidth: 0.7))

            HStack(spacing: 10) {
                Button { model.saveDraft(andWear: true) } label: { Label("wear it", systemImage: "cursorarrow.click.2") }
                    .buttonStyle(PillStyle(primary: true))
                    .keyboardShortcut(.return, modifiers: .command)
                Button { model.saveDraft(andWear: false) } label: { Text(model.draftIsSaved ? "saved" : "save to mine") }
                    .buttonStyle(PillStyle(primary: false))
                    .disabled(model.draftIsSaved)
                Spacer()
                Button { model.surprise() } label: { Label("surprise me", systemImage: "dice") }
                    .buttonStyle(LinkStyle(color: DS.link)).tight(13, .medium)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            Toggle(isOn: $model.liveTry) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("try it live on my mac").tight(13, .medium)
                    Text("every click changes your real cursor. leave this page to go back.").tight(11.5).foregroundStyle(DS.sub)
                }
            }
            .toggleStyle(.switch).controlSize(.small)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.7)))
        }
    }

    var animates: Bool { true }

    func frame(_ d: Date, _ g: Glyph = .arrow) -> Int {
        Int(d.timeIntervalSinceReferenceDate / CursorPainter.frameDuration(g, style)) % CursorPainter.animatedFrames
    }

    func stage(frame f: Int, spinner: Int) -> some View {
        let still = style.motion == .none && style.finish != .glitter && style.finish != .holo
        let ff = still ? 0 : f
        return VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 30) {
                sprite(.arrow, ff, 3.0)
                VStack(spacing: 18) { sprite(.pointing, ff, 1.5); sprite(.ibeam, ff, 1.4) }
                VStack(spacing: 18) { sprite(.wait, spinner, 1.3); sprite(.openHand, ff, 1.4) }
            }
            HStack(spacing: 18) {
                sprite(.closedHand, ff, 1.0); sprite(.copy, ff, 1.0); sprite(.forbidden, ff, 1.0)
                sprite(.crosshair, 0, 1.0); sprite(.resize(.e, both: true), 0, 1.0); sprite(.zoomIn, 0, 1.0)
            }
        }
        .id(style.hashValue)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .animation(DS.spring, value: style.hashValue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func sprite(_ g: Glyph, _ f: Int, _ scale: CGFloat) -> some View {
        let img = PreviewCache.shared.image(style: style, g, frame: f, k: 2)
        let s = scale / 2 / max(1, style.scale * 0.8)
        return Image(nsImage: img).resizable().interpolation(style.shape == .pixel ? .none : .high)
            .frame(width: img.size.width * s, height: img.size.height * s)
    }

    func bgChip(_ dark: Bool, _ icon: String) -> some View {
        Button { darkStage = dark } label: {
            Image(systemName: icon).font(.ui(11, .semibold))
                .foregroundStyle(darkStage == dark ? DS.ink : DS.sub)
                .frame(width: 26, height: 26)
                .background(Circle().fill(darkStage == dark ? Color.white : Color.white.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .help(dark ? "dark background" : "light background")
    }
}

// MARK: - Steps

private struct Steps: View {
    @EnvironmentObject var model: AppModel
    @State private var fineTune = false

    var s: CursorStyle { model.draft.style }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            step(1, "shape", "the body every cursor state is built on") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(ArrowShape.allCases) { shape in
                        OptionTile(label: shape.title, selected: s.shape == shape) {
                            var st = s; st.shape = shape
                            return PreviewCache.shared.image(style: st, .arrow, k: 1.9)
                        } action: { set { $0.shape = shape } }
                    }
                }
            }

            step(2, "color", "one colour, or a gradient. pick your own at the end.") {
                VStack(alignment: .leading, spacing: 10) {
                    FlowRow(spacing: 6, lineSpacing: 6) {
                        ForEach(Catalog.colors + Catalog.pastels + [("White", 0xffffff), ("Black", 0x111111)], id: \.0) { c in
                            Swatch(colors: [RGBA(c.1)], selected: s.fill == [RGBA(c.1)], help: c.0.lowercased()) { setFill([RGBA(c.1)]) }
                        }
                    }
                    FlowRow(spacing: 6, lineSpacing: 6) {
                        ForEach(Catalog.gradients, id: \.0) { g in
                            let cs = g.1.map { RGBA($0) }
                            Swatch(colors: cs, selected: s.fill == cs, wide: true, help: g.0.lowercased()) { setFill(cs) }
                        }
                    }
                    HStack(spacing: 14) {
                        Text("your own").tight(12.5, .medium).foregroundStyle(DS.sub)
                        ForEach(s.fill.indices, id: \.self) { i in
                            ColorPicker("", selection: Binding(get: { s.fill[i].color },
                                                               set: { c in set { st in if i < st.fill.count { st.fill[i] = RGBA(NSColor(c)) } } }), supportsOpacity: true)
                                .labelsHidden()
                        }
                        Button { set { if $0.fill.count < 4 { $0.fill.append($0.fill.last!.hueShifted(0.1)) } } } label: { Label("gradient stop", systemImage: "plus") }
                            .buttonStyle(LinkStyle(color: DS.sub)).tight(12)
                            .disabled(s.fill.count >= 4)
                        if s.fill.count > 1 {
                            Button { set { $0.fill.removeLast() } } label: { Image(systemName: "minus") }
                                .buttonStyle(LinkStyle(color: DS.sub)).tight(12)
                        }
                    }
                }
            }

            step(3, "finish", "what it's made of") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Finish.allCases) { f in
                        OptionTile(label: f.title, selected: s.finish == f) {
                            var st = s; st.finish = f; st.gloss = false
                            return PreviewCache.shared.image(style: st, .arrow, k: 1.9)
                        } action: { set { $0.finish = f; $0.gloss = false } }
                    }
                    OptionTile(label: "glass", selected: s.gloss && s.finish == .flat) {
                        var st = s; st.finish = .flat; st.gloss = true; st.fill = st.fill.map { $0.alpha(0.55) }
                        return PreviewCache.shared.image(style: st, .arrow, k: 1.9)
                    } action: { set { $0.finish = .flat; $0.gloss = true; $0.fill = $0.fill.map { $0.alpha(min($0.a, 0.55)) } } }
                }
            }

            step(4, "outline", "the rim that keeps it visible on any background") {
                HStack(spacing: 8) {
                    chip("white", s.outline == .white && s.outlineWidth > 0) { set { $0.outline = .white; if $0.outlineWidth == 0 { $0.outlineWidth = 1.3 } } }
                    chip("black", s.outline == RGBA(0x111111) && s.outlineWidth > 0) { set { $0.outline = RGBA(0x111111); if $0.outlineWidth == 0 { $0.outlineWidth = 1.2 } } }
                    chip("matching", s.outline == s.fill[0].mix(.black, 0.55)) { set { $0.outline = $0.fill[0].mix(.black, 0.55); if $0.outlineWidth == 0 { $0.outlineWidth = 1.1 } } }
                    chip("none", s.outlineWidth == 0) { set { $0.outlineWidth = 0 } }
                    ColorPicker("", selection: Binding(get: { s.outline.color }, set: { c in set { $0.outline = RGBA(NSColor(c)); if $0.outlineWidth == 0 { $0.outlineWidth = 1.2 } } }), supportsOpacity: true)
                        .labelsHidden()
                    Spacer()
                    chip("thin", s.outlineWidth > 0 && s.outlineWidth < 1.05) { set { $0.outlineWidth = 0.9 } }
                    chip("regular", s.outlineWidth >= 1.05 && s.outlineWidth < 1.5) { set { $0.outlineWidth = 1.3 } }
                    chip("bold", s.outlineWidth >= 1.5) { set { $0.outlineWidth = 1.9 } }
                }
            }

            step(5, "glow", "a soft light around every state") {
                HStack(spacing: 8) {
                    chip("off", s.glow == nil) { set { $0.glow = nil; if $0.shadow == 0 { $0.shadow = 0.38 } } }
                    chip("soft", s.glow != nil && s.glowRadius < 5) { set { $0.glow = $0.fill[0].alpha(0.75); $0.glowRadius = 3.5; $0.shadow = 0 } }
                    chip("neon", s.glow != nil && s.glowRadius >= 5) { set { $0.glow = ($0.outlineWidth > 0 && $0.outline != .white ? $0.outline : $0.fill[0]).alpha(0.95); $0.glowRadius = 6.5; $0.shadow = 0 } }
                    if s.glow != nil {
                        ColorPicker("", selection: Binding(get: { (s.glow ?? .white).color }, set: { c in set { $0.glow = RGBA(NSColor(c)) } }), supportsOpacity: true)
                            .labelsHidden()
                            .transition(.opacity.combined(with: .scale))
                    }
                    Spacer()
                    Text("shadow").tight(12.5).foregroundStyle(DS.sub)
                    chip("none", s.shadow == 0) { set { $0.shadow = 0 } }
                    chip("soft", s.shadow > 0 && s.shadow < 0.5) { set { $0.shadow = 0.38 } }
                    chip("strong", s.shadow >= 0.5) { set { $0.shadow = 0.65 } }
                }
            }

            step(6, "motion", "only animated looks move. the wait spinner always spins.") {
                HStack(spacing: 8) {
                    ForEach(Motion.allCases) { m in chip(m.title, s.motion == m) { set { $0.motion = m } } }
                }
            }

            step(7, "size", "the base size. the size slider in browse scales it further.") {
                HStack(spacing: 8) {
                    ForEach([("s", 0.85), ("m", 1.0), ("l", 1.3), ("xl", 1.6), ("xxl", 2.1)], id: \.0) { item in
                        chip(item.0, abs(s.scale - item.1) < 0.05) { set { $0.scale = item.1 } }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Button { withAnimation(DS.spring) { fineTune.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right").font(.ui(11, .semibold)).rotationEffect(.degrees(fineTune ? 90 : 0))
                        Text("fine tune").tight(14, .medium)
                    }
                    .foregroundStyle(DS.sub)
                }
                .buttonStyle(.plain)
                if fineTune {
                    VStack(spacing: 10) {
                        slider("gradient angle", Binding(get: { s.angle }, set: { v in set { $0.angle = v } }), 0...360, "%.0f°")
                        slider("outline width", Binding(get: { s.outlineWidth }, set: { v in set { $0.outlineWidth = v } }), 0...2.6, "%.1f")
                        slider("glow size", Binding(get: { s.glowRadius }, set: { v in set { $0.glowRadius = v } }), 1...10, "%.0f")
                        slider("shadow", Binding(get: { s.shadow }, set: { v in set { $0.shadow = v } }), 0...0.8, "%.2f")
                        slider("size", Binding(get: { s.scale }, set: { v in set { $0.scale = v } }), 0.8...2.4, "%.2gx")
                        HStack {
                            Text("badges and spinner").tight(12.5).foregroundStyle(DS.sub).frame(width: 130, alignment: .leading)
                            ColorPicker("", selection: Binding(get: { s.accent.color }, set: { c in set { $0.accent = RGBA(NSColor(c)) } })).labelsHidden()
                            Spacer()
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.7)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .tint(DS.link)
        .padding(.top, 6)
        .animation(DS.spring, value: s)
    }

    // MARK: helpers

    func set(_ change: (inout CursorStyle) -> Void) {
        var st = model.draft.style
        change(&st)
        withAnimation(DS.spring) { model.draft.style = st }
    }

    /// Picking a colour also keeps the cursor readable: a light body gets a dark
    /// rim, a dark body a light one, and badges follow the colour.
    func setFill(_ cs: [RGBA]) {
        set { st in
            let wasGlass = st.gloss && st.finish == .flat
            st.fill = wasGlass ? cs.map { $0.alpha(0.55) } : cs
            let lum = cs.map(\.luminance).reduce(0, +) / Double(cs.count)
            if st.outlineWidth > 0, st.finish != .hollow {
                if lum > 0.75, st.outline.luminance > 0.75 { st.outline = RGBA(0x111111) }
                if lum < 0.25, st.outline.luminance < 0.25 { st.outline = .white }
            }
            st.accent = cs[0].luminance > 0.75 ? cs[0].mix(.black, 0.4) : cs[0]
            if let g = st.glow { st.glow = cs[0].alpha(g.a) }
        }
    }

    func step<C: View>(_ n: Int, _ title: String, _ hint: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(n)").tight(12, .semibold)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(DS.aqua))
                    .overlay(Circle().strokeBorder(DS.aquaBorder.opacity(0.8), lineWidth: 0.6))
                Text(title).tight(17, .semibold)
                Text(hint).tight(12.5).foregroundStyle(DS.sub).lineLimit(1)
            }
            content()
        }
    }

    func chip(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).tight(13, on ? .semibold : .regular)
                .foregroundStyle(on ? DS.ink : DS.sub)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.45)))
                .overlay(Capsule().strokeBorder(on ? DS.link.opacity(0.9) : DS.hairline, lineWidth: on ? 1.3 : 0.6))
                .shadow(color: .black.opacity(on ? 0.06 : 0), radius: 4, y: 2)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(DS.spring, value: on)
    }

    func slider(_ label: String, _ v: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String) -> some View {
        HStack(spacing: 10) {
            Text(label).tight(12.5).foregroundStyle(DS.sub).frame(width: 130, alignment: .leading)
            Slider(value: v, in: range).controlSize(.small)
            Text(String(format: fmt, v.wrappedValue)).tight(11.5).foregroundStyle(DS.faint).monospacedDigit().frame(width: 40, alignment: .trailing)
        }
    }
}

/// A big clickable choice with a rendered preview of the result.
private struct OptionTile: View {
    let label: String
    let selected: Bool
    let image: () -> NSImage
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                let img = image()
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                    DotGrid(spacing: 10, color: .black.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Image(nsImage: img).resizable().interpolation(.high)
                        .frame(width: img.size.width * fit(img), height: img.size.height * fit(img))
                        .scaleEffect(hover ? 1.08 : 1)
                }
                .frame(height: 62)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? DS.link : DS.hairline, lineWidth: selected ? 1.8 : 0.6))
                .shadow(color: .black.opacity(selected ? 0.08 : 0.03), radius: selected ? 8 : 3, y: 3)
                Text(label).tight(11.5, selected ? .semibold : .regular).foregroundStyle(selected ? DS.ink : DS.sub)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(DS.spring, value: hover)
        .animation(DS.spring, value: selected)
    }

    func fit(_ img: NSImage) -> CGFloat { min(1, 56 / max(img.size.width, img.size.height, 1)) }
}

/// A round (or pill, for gradients) colour choice.
private struct Swatch: View {
    let colors: [RGBA]
    let selected: Bool
    var wide = false
    var help = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if wide {
                    Capsule().fill(LinearGradient(colors: colors.map(\.color), startPoint: .leading, endPoint: .trailing))
                } else {
                    Circle().fill(colors[0].color)
                }
            }
            .frame(width: wide ? 50 : 24, height: 24)
            .overlay {
                if wide { Capsule().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.6) } else { Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.6) }
            }
            .padding(3)
            .overlay {
                if selected {
                    if wide { Capsule().strokeBorder(DS.link, lineWidth: 2) } else { Circle().strokeBorder(DS.link, lineWidth: 2) }
                }
            }
            .scaleEffect(hover ? 1.12 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
        .animation(DS.spring, value: hover)
        .animation(DS.spring, value: selected)
    }
}
