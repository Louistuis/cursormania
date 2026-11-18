import SwiftUI

// MARK: - Main window

struct MainView: View {
    @EnvironmentObject var model: AppModel
    var renderMode = false

    var body: some View {
        ZStack(alignment: .top) {
            DS.canvas.ignoresSafeArea()
            DotGrid().ignoresSafeArea()

            Group {
                switch model.page {
                case .browse: page { BrowsePage(lazy: !renderMode) }
                case .create: CreatePage(renderMode: renderMode).padding(.top, 52)
                case .mine: page { MinePage() }
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
            .id(model.page)

            TopBar()

            if model.page != .create {
                WearingDock()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
            }
            if let toast = model.toast {
                Toast(text: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, model.page == .create ? 22 : 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .top)
        .frame(minWidth: 1040, minHeight: 700)
        .environment(\.colorScheme, .light)
        .animation(DS.softSpring, value: model.page)
        .sheet(isPresented: $model.showStates) { StatesSheet().environmentObject(model) }
    }

    @ViewBuilder func page<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        if renderMode {
            c().padding(.top, 60).padding(.horizontal, 28).padding(.bottom, 110)
        } else {
            ScrollView {
                c().padding(.top, 60).padding(.horizontal, 28).padding(.bottom, 110)
            }
            .scrollIndicators(.never)
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                Spacer().frame(width: 70)
                Text("cursormania").tight(15, .semibold).foregroundStyle(DS.ink)
                Chip(text: "v\(AppInfo.version)")
                Spacer()
                if model.page == .browse {
                    SearchField()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
                }
                Button { model.shuffle() } label: { Label("shuffle", systemImage: "shuffle").labelStyle(.titleAndIcon) }
                    .buttonStyle(LinkStyle(color: DS.sub)).tight(13)
                    .help("wear a random look")
            }
            PageSwitcher()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(
            LinearGradient(colors: [DS.canvas, DS.canvas.opacity(0.85), DS.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -18)
                .allowsHitTesting(false)
        )
        .animation(DS.spring, value: model.page)
    }
}

/// The three places in the app, as one glass segmented control.
struct PageSwitcher: View {
    @EnvironmentObject var model: AppModel
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            item(.browse, "browse", "square.grid.2x2")
            item(.create, "create", "paintbrush.pointed")
            item(.mine, model.custom.isEmpty ? "mine" : "mine \(model.custom.count)", "heart.text.square")
        }
        .padding(3)
        .glassEffect(.regular, in: Capsule())
    }

    func item(_ p: Page, _ title: String, _ icon: String) -> some View {
        Button {
            if p == .create, model.page != .create { model.startCreate(from: nil) } else { model.page = p }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.ui(11.5, .semibold))
                Text(title)
            }
            .tight(13, model.page == p ? .semibold : .regular)
            .foregroundStyle(model.page == p ? DS.ink : DS.sub)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background {
                if model.page == p {
                    Capsule().fill(Color.white).shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                        .matchedGeometryEffect(id: "pill", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(p == .browse ? "1" : p == .create ? "2" : "3", modifiers: .command)
    }
}

struct SearchField: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.ui(12, .medium)).foregroundStyle(DS.sub)
            TextField("search \(Catalog.themes.count) looks", text: $model.search)
                .textFieldStyle(.plain)
                .tight(13)
                .frame(width: 150)
            if !model.search.isEmpty {
                Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(DS.faint) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}

// MARK: - Browse

struct BrowsePage: View {
    @EnvironmentObject var model: AppModel
    var lazy = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("pick a look").tight(34, .medium)
                Text("click any card and every cursor on your mac changes. hover a card to preview it right here.")
                    .tight(14).foregroundStyle(DS.sub)
            }
            SectionChips()
            Gallery(lazy: lazy)
        }
    }
}

struct SectionChips: View {
    @EnvironmentObject var model: AppModel

    var sections: [Section] {
        [.all, .favorites] + ThemeCategory.allCases.filter { $0 != .custom }.map { .category($0) }
    }

    var body: some View {
        FlowRow(spacing: 2, lineSpacing: 4) {
            ForEach(sections, id: \.self) { s in
                Button {
                    withAnimation(DS.softSpring) { model.section = s; model.search = "" }
                } label: {
                    HStack(spacing: 5) {
                        Text(s.title)
                        Text("\(model.count(s))").foregroundStyle(DS.faint).monospacedDigit()
                    }
                    .tight(13, model.section == s && model.search.isEmpty ? .medium : .regular)
                }
                .buttonStyle(LinkStyle(active: model.section == s && model.search.isEmpty, color: DS.sub))
            }
        }
    }
}

struct Gallery: View {
    @EnvironmentObject var model: AppModel
    var lazy = true
    var themes: [CursorTheme]? = nil
    let columns = [GridItem(.adaptive(minimum: 196, maximum: 270), spacing: 18, alignment: .top)]

    var body: some View {
        let list = themes ?? model.visibleThemes
        Group {
            if list.isEmpty {
                VStack(spacing: 8) {
                    Text(model.section == .favorites ? "( ˘ω˘ )" : "(¬_¬)").tight(28).foregroundStyle(DS.faint)
                    Text(model.section == .favorites ? "tap the heart on any card to keep it here" : "nothing matches that")
                        .tight(14).foregroundStyle(DS.sub)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else if lazy {
                LazyVGrid(columns: columns, spacing: 22) { ForEach(list) { card($0) } }
            } else {
                Grid(horizontalSpacing: 18, verticalSpacing: 22) {
                    ForEach(Array(stride(from: 0, to: min(list.count, 20), by: 5)), id: \.self) { i in
                        GridRow { ForEach(list[i..<min(i + 5, list.count)]) { card($0) } }
                    }
                }
            }
        }
    }

    func card(_ t: CursorTheme) -> some View {
        ThemeCard(theme: t, active: model.activeID == t.id, favorite: model.favorites.contains(t.id))
    }
}

// MARK: - Card

struct ThemeCard: View {
    @EnvironmentObject var model: AppModel
    let theme: CursorTheme
    let active: Bool
    let favorite: Bool
    @State private var hover = false

    var dark: Bool { CardLook.isDark(theme.style, theme.category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            MacWindow(title: theme.name.lowercased(), highlighted: active, dark: dark) {
                ZStack(alignment: .topTrailing) {
                    stage
                    if hover {
                        HStack(spacing: 4) {
                            iconButton(favorite ? "heart.fill" : "heart", favorite ? .pink : DS.sub, "favorite") { model.toggleFavorite(theme) }
                            iconButton("paintbrush.pointed", DS.sub, "remix in create") { model.startCreate(from: theme) }
                            if theme.category == .custom {
                                iconButton("trash", DS.sub, "delete") { model.deleteCustom(theme) }
                            }
                        }
                        .padding(7)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                    }
                }
            }
            HStack(spacing: 6) {
                if active {
                    Circle().fill(DS.link).frame(width: 6, height: 6)
                    Text("wearing").tight(11.5, .medium).foregroundStyle(DS.link)
                } else {
                    Text(theme.category == .custom ? "mine" : theme.category.title).tight(11.5).foregroundStyle(DS.faint)
                }
                Spacer()
                if favorite {
                    Image(systemName: "heart.fill").font(.ui(10)).foregroundStyle(.pink)
                }
                if hover && !active {
                    Text("click to wear").tight(11.5, .medium).foregroundStyle(DS.link)
                        .transition(.opacity)
                }
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
            Button("remix in create") { model.startCreate(from: theme) }
            if theme.category == .custom {
                Divider()
                Button("delete", role: .destructive) { model.deleteCustom(theme) }
            }
        }
    }

    func iconButton(_ name: String, _ tint: Color, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.ui(11, .semibold)).foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    var stage: some View {
        ZStack {
            CardLook.backdrop(theme.style, theme.category)
            if hover {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
                    CardFigures(style: theme.style, frame: theme.style.motion == .none && theme.style.finish != .glitter ? 0 : frame(ctx.date), spinner: frame(ctx.date, glyph: .wait), lift: true)
                }
            } else {
                CardFigures(style: theme.style, frame: 0, spinner: 0, lift: false)
            }
        }
        .frame(height: 118)
    }

    func frame(_ d: Date, glyph: Glyph = .arrow) -> Int {
        Int(d.timeIntervalSinceReferenceDate / CursorPainter.frameDuration(glyph, theme.style)) % CursorPainter.animatedFrames
    }
}

/// The little scene inside every card: a big arrow plus a few other states.
struct CardFigures: View {
    let style: CursorStyle
    let frame: Int
    let spinner: Int
    var lift = false
    var zoom: CGFloat = 1

    var body: some View {
        HStack(alignment: .center, spacing: 14 * zoom) {
            sprite(.arrow, frame, 1.75)
            VStack(spacing: 10 * zoom) { sprite(.pointing, frame, 1.0); sprite(.ibeam, frame, 0.95) }
            VStack(spacing: 10 * zoom) { sprite(.wait, spinner, 0.85); sprite(.closedHand, frame, 0.95) }
        }
        .scaleEffect(lift ? 1.04 : 1)
    }

    func sprite(_ g: Glyph, _ f: Int, _ scale: CGFloat) -> some View {
        let img = PreviewCache.shared.image(style: style, g, frame: f)
        let s = scale * zoom / max(1, style.scale * 0.85)
        return Image(nsImage: img).resizable().interpolation(style.shape == .pixel ? .none : .high)
            .frame(width: img.size.width * s, height: img.size.height * s)
    }
}

enum CardLook {
    static func isDark(_ s: CursorStyle, _ c: ThemeCategory) -> Bool {
        c == .neon || s.glow != nil
    }

    @ViewBuilder static func backdrop(_ s: CursorStyle, _ c: ThemeCategory, dark forced: Bool? = nil) -> some View {
        if forced ?? isDark(s, c) {
            LinearGradient(colors: [Color(white: 0.1), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            DotGrid(spacing: 14, color: .white.opacity(0.07))
        } else if c == .glass || s.finish == .holo {
            LinearGradient(colors: [Color(red: 0.75, green: 0.86, blue: 1), Color(red: 1, green: 0.84, blue: 0.9), Color(red: 1, green: 0.95, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.white
            DotGrid(spacing: 14, color: .black.opacity(0.07))
        }
    }
}

// MARK: - Mine

struct MinePage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("your cursors").tight(34, .medium)
                    Text(model.custom.isEmpty ? "looks you make in create land here." : "click one to wear it. hover for edit and delete.")
                        .tight(14).foregroundStyle(DS.sub)
                }
                Spacer()
                Button { model.startCreate(from: nil) } label: { Label("make a new one", systemImage: "plus") }
                    .buttonStyle(PillStyle(primary: true))
            }
            if model.custom.isEmpty {
                VStack(spacing: 14) {
                    Text("( ･ω･)つ").tight(34).foregroundStyle(DS.faint)
                    Text("nothing here yet. it takes about ten seconds to make one.").tight(15).foregroundStyle(DS.sub)
                    Button { model.startCreate(from: nil) } label: { Text("start making") }
                        .buttonStyle(PillStyle(primary: false))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 80)
            } else {
                Gallery(themes: model.custom)
            }
            if !model.favorites.isEmpty {
                Text("favorites").tight(20, .medium).padding(.top, 14)
                Gallery(themes: model.allThemes.filter { model.favorites.contains($0.id) })
            }
        }
    }
}

// MARK: - Dock

/// Always-visible strip: what you're wearing, its size, and the way back.
struct WearingDock: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let t = model.active {
                    let img = PreviewCache.shared.image(t, .arrow)
                    Image(nsImage: img).resizable().interpolation(t.style.shape == .pixel ? .none : .high)
                        .frame(width: img.size.width * 0.8 / max(1, t.style.scale * 0.8), height: img.size.height * 0.8 / max(1, t.style.scale * 0.8))
                        .id(t.id)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Image(systemName: "cursorarrow").font(.ui(18, .medium)).foregroundStyle(DS.sub)
                }
            }
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.white.opacity(0.7)))

            VStack(alignment: .leading, spacing: 1) {
                Text(model.active == nil ? "stock macOS cursor" : "wearing").tight(11).foregroundStyle(DS.sub)
                Text(model.active?.name.lowercased() ?? "pick any card").tight(14, .semibold).lineLimit(1)
                    .contentTransition(.interpolate)
            }
            .frame(width: 150, alignment: .leading)

            Divider().frame(height: 26)

            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller").font(.ui(11)).foregroundStyle(DS.sub)
                Slider(value: $model.size, in: 0.75...2.5).controlSize(.small).frame(width: 120).tint(DS.link)
                Text(String(format: "%.2gx", model.size)).tight(12).foregroundStyle(DS.sub).monospacedDigit().frame(width: 34, alignment: .leading)
            }
            .help("size of every cursor")

            Button { model.showStates = true } label: { Text("all 38 states") }
                .buttonStyle(LinkStyle(color: DS.sub)).tight(12.5)
                .disabled(model.active == nil)

            Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                Text("keep after restart").tight(12).foregroundStyle(DS.sub)
            }
            .toggleStyle(.switch).controlSize(.mini)

            Button { model.restore() } label: { Text("restore") }
                .buttonStyle(PillStyle(primary: false, compact: true))
                .disabled(model.active == nil)
                .opacity(model.active == nil ? 0.5 : 1)
        }
        .padding(.leading, 8).padding(.trailing, 10).padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .animation(DS.softSpring, value: model.activeID)
    }
}

struct StatesSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        let t = model.active ?? Catalog.themes[0]
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.name.lowercased()).tight(26, .medium)
                    Text("every state of this look. hover one to try it.").tight(13).foregroundStyle(DS.sub)
                }
                Spacer()
                Button("done") { dismiss() }.buttonStyle(PillStyle(primary: true, compact: true)).keyboardShortcut(.defaultAction)
            }
            MacWindow(title: "\(t.name.lowercased()).cape", highlighted: true) { StatesBoard(theme: t) }
        }
        .padding(24)
        .frame(width: 820)
        .background(ZStack { DS.canvas; DotGrid() })
        .environment(\.colorScheme, .light)
    }
}

// MARK: - States board

/// Every cursor state of a style, grouped, and live: hover a tile and the
/// pointer inside the app becomes that cursor.
struct StatesBoard: View {
    let theme: CursorTheme
    var compact = false

    var body: some View {
        let dark = CardLook.isDark(theme.style, theme.category)
        FlowRow(spacing: compact ? 14 : 22, lineSpacing: compact ? 10 : 14) {
            ForEach(RoleGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.title).tight(11, .medium).foregroundStyle(dark ? Color.white.opacity(0.5) : DS.faint)
                    FlowRow(spacing: 2, maxWidth: compact ? 520 : 680) {
                        ForEach(CursorRole.all.filter { $0.group == group }) { role in
                            StateTile(style: theme.style, role: role, dark: dark, size: compact ? 42 : 50, zoom: compact ? 1 : 1.15)
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
    let style: CursorStyle
    let role: CursorRole
    let dark: Bool
    var size: CGFloat = 46
    var zoom: Double = 1
    @State private var hover = false

    var animated: Bool { CursorPainter.isAnimated(role.glyph, style) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hover ? (dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045)) : Color.clear)
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in glyph(frame: frameIndex(ctx.date)) }
            } else {
                glyph(frame: 0)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(hover ? 1.08 : 1)
        .animation(DS.spring, value: hover)
        .onHover { hover = $0 }
        .pointerStyle(.image(Image(nsImage: PreviewCache.shared.image(style: style, role.glyph)), hotSpot: PreviewCache.shared.hotspot(style: style, role.glyph)))
        .help(role.title)
    }

    func frameIndex(_ d: Date) -> Int {
        Int(d.timeIntervalSinceReferenceDate / CursorPainter.frameDuration(role.glyph, style)) % CursorPainter.animatedFrames
    }

    func glyph(frame: Int) -> some View {
        let img = PreviewCache.shared.image(style: style, role.glyph, frame: frame, k: zoom)
        let fit = min(1, (size - 4) / max(img.size.width, img.size.height))
        return Image(nsImage: img).resizable().interpolation(style.shape == .pixel ? .none : .high)
            .frame(width: img.size.width * fit, height: img.size.height * fit)
    }
}

/// Wraps children onto as many lines as needed.
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }
}
