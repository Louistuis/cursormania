import SwiftUI

// MARK: - Main window

struct MainView: View {
    @EnvironmentObject var model: AppModel
    var renderMode = false

    var body: some View {
        ZStack(alignment: .top) {
            DS.canvas.ignoresSafeArea()
            DotGrid().ignoresSafeArea()
            if renderMode {
                content.padding(.top, 60)
            } else {
                ScrollView { content.padding(.top, 58) }
                    .scrollIndicators(.never)
            }
            TopBar()
            if let toast = model.toast {
                Toast(text: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .top)
        .frame(minWidth: 980, minHeight: 680)
        .environment(\.colorScheme, .light)
        .sheet(item: $model.editing) { theme in
            BuilderView(theme: theme).environmentObject(model)
        }
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            Hero()
            SectionTabs(scrolls: !renderMode)
            Gallery(lazy: !renderMode)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 48)
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searching: Bool

    var body: some View {
        HStack(spacing: 6) {
            Spacer().frame(width: 70)
            Text("cursorspacex").tight(15, .semibold).foregroundStyle(DS.ink)
            Chip(text: "v\(AppInfo.version)")
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.ui(12, .medium)).foregroundStyle(DS.sub)
                TextField("search 80+ looks", text: $model.search)
                    .textFieldStyle(.plain)
                    .tight(13)
                    .focused($searching)
                    .frame(width: 170)
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(DS.faint) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: Capsule())
            Button { model.shuffle() } label: { Text("shuffle") }
                .buttonStyle(LinkStyle(color: DS.sub)).tight(13)
            Button { model.editing = BuilderView.blank(from: model.active) } label: { Text("make your own") }
                .buttonStyle(LinkStyle(color: DS.link)).tight(13, .medium)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .padding(.top, 0)
        .background(.ultraThinMaterial.opacity(0.0))
        .background(
            LinearGradient(colors: [DS.canvas, DS.canvas.opacity(0.82), DS.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Hero

struct Hero: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.active ?? Catalog.themes[0]
        HStack(alignment: .top, spacing: 26) {
            MacWindow(title: model.active == nil ? "macos.cape" : "\(theme.name.lowercased()).cape", highlighted: model.active != nil) {
                StatesBoard(theme: theme)
                    .id(theme.id + "\(theme.style.hashValue)")
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                Text(model.active == nil ? "the stock macOS cursor is on" : "now wearing")
                    .tight(13).foregroundStyle(DS.sub)
                Text(model.active?.name.lowercased() ?? "pick a look")
                    .tight(40, .medium)
                    .foregroundStyle(DS.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.interpolate)
                if let t = model.active {
                    HStack(spacing: 6) {
                        Chip(text: t.category.title)
                        if model.favorites.contains(t.id) { Chip(text: "favorite", tint: .pink) }
                        if model.applying { ProgressView().controlSize(.mini) }
                    }
                } else {
                    Text("click any look below and every cursor on your mac changes, instantly.")
                        .tight(14).foregroundStyle(DS.sub).fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("size").tight(13, .medium)
                        Spacer()
                        Text(String(format: "%.2gx", model.size)).tight(13).foregroundStyle(DS.sub).monospacedDigit()
                    }
                    Slider(value: $model.size, in: 0.75...2.5)
                        .controlSize(.small)
                        .tint(DS.link)
                }
                .padding(.top, 4)

                HStack(spacing: 10) {
                    Button { model.editing = BuilderView.blank(from: model.active) } label: { Text(model.active == nil ? "make your own" : "remix this") }
                        .buttonStyle(PillStyle(primary: true))
                    Button { model.restore() } label: { Text("restore") }
                        .buttonStyle(PillStyle(primary: false))
                        .disabled(model.active == nil)
                        .opacity(model.active == nil ? 0.55 : 1)
                }
                .padding(.top, 2)

                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    Text("keep my cursor after a restart").tight(12.5).foregroundStyle(DS.sub)
                }
                .toggleStyle(.switch).controlSize(.mini)
                .padding(.top, 2)
                Spacer(minLength: 0)
            }
            .frame(width: 270)
            .padding(.top, 6)
        }
        .animation(DS.softSpring, value: model.activeID)
    }
}

/// Every cursor state of a theme, grouped, and live: hover a tile and the
/// pointer inside the app becomes that cursor.
struct StatesBoard: View {
    let theme: CursorTheme
    var compact = false
    @State private var hovered: String?

    var body: some View {
        let dark = theme.category == .neon || theme.style.glow != nil
        FlowRow(spacing: compact ? 14 : 22, lineSpacing: compact ? 10 : 14) {
            ForEach(RoleGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.title).tight(11, .medium).foregroundStyle(dark ? Color.white.opacity(0.5) : DS.faint)
                    FlowRow(spacing: 2, maxWidth: compact ? 520 : 680) {
                        ForEach(CursorRole.all.filter { $0.group == group }) { role in
                            StateTile(theme: theme, role: role, dark: dark, size: compact ? 42 : 50, zoom: compact ? 1 : 1.15)
                        }
                    }
                }
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dark ? Color(white: 0.06) : Color.white)
    }
}

struct StateTile: View {
    let theme: CursorTheme
    let role: CursorRole
    let dark: Bool
    var size: CGFloat = 46
    var zoom: Double = 1
    @State private var hover = false

    var animated: Bool { CursorPainter.isAnimated(role.glyph, theme.style) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hover ? (dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045)) : Color.clear)
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
                    glyph(frame: frameIndex(ctx.date))
                }
            } else {
                glyph(frame: 0)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(hover ? 1.08 : 1)
        .animation(DS.spring, value: hover)
        .onHover { hover = $0 }
        .pointerStyle(.image(Image(nsImage: PreviewCache.shared.image(theme, role.glyph)), hotSpot: PreviewCache.shared.hotspot(theme, role.glyph)))
        .help(role.title)
    }

    func frameIndex(_ d: Date) -> Int {
        let dur = CursorPainter.frameDuration(role.glyph, theme.style)
        return Int(d.timeIntervalSinceReferenceDate / dur) % CursorPainter.animatedFrames
    }

    func glyph(frame: Int) -> some View {
        let img = PreviewCache.shared.image(theme, role.glyph, frame: frame, k: zoom)
        let fit = min(1, (size - 4) / max(img.size.width, img.size.height))
        return Image(nsImage: img).resizable().interpolation(theme.style.shape == .pixel ? .none : .high)
            .frame(width: img.size.width * fit, height: img.size.height * fit)
    }
}

/// Wraps tiles onto as many lines as needed.
struct FlowRow: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat? = nil
    var maxWidth: CGFloat = 10_000
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = min(proposal.width ?? maxWidth, maxWidth)
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, used: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += row + (lineSpacing ?? spacing); row = 0 }
            x += sz.width + spacing; row = max(row, sz.height); used = max(used, x - spacing)
        }
        return CGSize(width: proposal.width == nil ? used : width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.minX + min(bounds.width, maxWidth) + 0.5 { x = bounds.minX; y += row + (lineSpacing ?? spacing); row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; row = max(row, sz.height)
        }
    }
}

// MARK: - Sections

struct SectionTabs: View {
    @EnvironmentObject var model: AppModel
    var scrolls = true

    var sections: [Section] {
        var s: [Section] = [.all, .favorites]
        s += ThemeCategory.allCases.filter { $0 != .custom || !model.custom.isEmpty }.map { .category($0) }
        return s
    }

    var body: some View {
        if scrolls { ScrollView(.horizontal) { tabs }.scrollIndicators(.never) } else { tabs }
    }

    var tabs: some View {
            HStack(spacing: 2) {
                ForEach(sections, id: \.self) { s in
                    Button {
                        withAnimation(DS.softSpring) { model.section = s }
                    } label: {
                        HStack(spacing: 5) {
                            Text(s.title)
                            Text("\(model.count(s))").foregroundStyle(DS.faint).monospacedDigit()
                        }
                        .tight(13, model.section == s ? .medium : .regular)
                    }
                    .buttonStyle(LinkStyle(active: model.section == s, color: DS.sub))
                }
            }
    }
}

struct Gallery: View {
    @EnvironmentObject var model: AppModel
    var lazy = true
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 18, alignment: .top)]

    var body: some View {
        let themes = model.visibleThemes
        Group {
            if themes.isEmpty {
                VStack(spacing: 8) {
                    Text(model.section == .favorites ? "( ˘ω˘ )" : "(¬_¬)").tight(28).foregroundStyle(DS.faint)
                    Text(model.section == .favorites ? "tap the heart on any look to keep it here" : "nothing matches that")
                        .tight(14).foregroundStyle(DS.sub)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else if lazy {
                LazyVGrid(columns: columns, spacing: 22) { cards(themes) }
            } else {
                Grid(horizontalSpacing: 18, verticalSpacing: 22) {
                    ForEach(Array(stride(from: 0, to: themes.count, by: 4)), id: \.self) { i in
                        GridRow { ForEach(themes[i..<min(i + 4, themes.count)]) { card($0) } }
                    }
                }
            }
        }
    }

    @ViewBuilder func cards(_ themes: [CursorTheme]) -> some View {
        ForEach(themes) { card($0) }
    }

    func card(_ t: CursorTheme) -> some View {
        ThemeCard(theme: t, active: model.activeID == t.id, favorite: model.favorites.contains(t.id))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

// MARK: - Card

struct ThemeCard: View {
    @EnvironmentObject var model: AppModel
    let theme: CursorTheme
    let active: Bool
    let favorite: Bool
    @State private var hover = false

    var dark: Bool { theme.category == .neon || theme.style.glow != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            MacWindow(title: theme.name.lowercased(), highlighted: active, dark: dark) {
                stage
            }
            HStack(spacing: 6) {
                if active {
                    Circle().fill(DS.link).frame(width: 6, height: 6)
                    Text("wearing").tight(11.5, .medium).foregroundStyle(DS.link)
                } else {
                    Text(theme.category.title).tight(11.5).foregroundStyle(DS.faint)
                }
                Spacer()
                Button { model.toggleFavorite(theme) } label: {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .font(.ui(11.5, .semibold))
                        .foregroundStyle(favorite ? Color.pink : DS.faint)
                        .symbolEffect(.bounce, value: favorite)
                }
                .buttonStyle(.plain)
                .opacity(hover || favorite ? 1 : 0)
            }
            .padding(.horizontal, 4)
        }
        .offset(y: hover ? -3 : 0)
        .shadow(color: .black.opacity(hover ? 0.08 : 0), radius: 18, y: 14)
        .animation(DS.spring, value: hover)
        .animation(DS.spring, value: active)
        .onHover { hover = $0 }
        .pointerStyle(.image(Image(nsImage: PreviewCache.shared.image(theme, .arrow)), hotSpot: PreviewCache.shared.hotspot(theme, .arrow)))
        .onTapGesture { model.apply(theme) }
        .contextMenu {
            Button("wear it") { model.apply(theme) }
            Button(favorite ? "remove from favorites" : "add to favorites") { model.toggleFavorite(theme) }
            Button("remix") { model.editing = BuilderView.blank(from: theme) }
            if theme.category == .custom {
                Button("edit") { model.editing = theme }
                Divider()
                Button("delete", role: .destructive) { model.deleteCustom(theme) }
            }
        }
    }

    var stage: some View {
        ZStack {
            backdrop
            if hover && (theme.style.motion != .none) {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in figures(frame: frame(ctx.date)) }
            } else if hover {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in figures(frame: 0, spinner: frame(ctx.date, glyph: .wait)) }
            } else {
                figures(frame: 0)
            }
        }
        .frame(height: 118)
    }

    @ViewBuilder var backdrop: some View {
        if dark {
            LinearGradient(colors: [Color(white: 0.09), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            DotGrid(spacing: 14, color: .white.opacity(0.07))
        } else if theme.category == .glass {
            LinearGradient(colors: [Color(red: 0.75, green: 0.86, blue: 1), Color(red: 1, green: 0.84, blue: 0.9), Color(red: 1, green: 0.95, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.white
            DotGrid(spacing: 14, color: .black.opacity(0.07))
        }
    }

    func frame(_ d: Date, glyph: Glyph = .arrow) -> Int {
        Int(d.timeIntervalSinceReferenceDate / CursorPainter.frameDuration(glyph, theme.style)) % CursorPainter.animatedFrames
    }

    func figures(frame f: Int, spinner: Int? = nil) -> some View {
        HStack(alignment: .center, spacing: 14) {
            sprite(.arrow, f, scale: 1.75)
            VStack(spacing: 10) {
                sprite(.pointing, f, scale: 1.0)
                sprite(.ibeam, f, scale: 0.95)
            }
            VStack(spacing: 10) {
                sprite(.wait, spinner ?? f, scale: 0.85)
                sprite(.closedHand, f, scale: 0.95)
            }
        }
        .scaleEffect(hover ? 1.04 : 1)
    }

    func sprite(_ g: Glyph, _ f: Int, scale: CGFloat) -> some View {
        let img = PreviewCache.shared.image(theme, g, frame: f)
        let s = scale / max(1, theme.style.scale * 0.85)
        return Image(nsImage: img).resizable().interpolation(theme.style.shape == .pixel ? .none : .high)
            .frame(width: img.size.width * s, height: img.size.height * s)
    }
}

// MARK: - Toast

struct Toast: View {
    let text: String
    var body: some View {
        Text(text).tight(13, .medium).foregroundStyle(DS.ink)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}
