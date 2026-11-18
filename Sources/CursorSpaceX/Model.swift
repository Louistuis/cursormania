import AppKit
import SwiftUI
import ServiceManagement

/// Saved custom looks.
enum ThemeStore {
    static let customKey = "themes.custom"

    static func loadCustom() -> [CursorTheme] {
        guard let data = UserDefaults.standard.data(forKey: customKey) else { return [] }
        return (try? JSONDecoder().decode([CursorTheme].self, from: data)) ?? []
    }

    static func saveCustom(_ themes: [CursorTheme]) {
        if let data = try? JSONEncoder().encode(themes) { UserDefaults.standard.set(data, forKey: customKey) }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case browse, create, mine
    var id: String { rawValue }
}

enum Section: Hashable {
    case all, favorites, category(ThemeCategory)
    var title: String {
        switch self {
        case .all: return "all"
        case .favorites: return "favorites"
        case .category(let c): return c.title
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    /// Off for renders and screenshots, so they never touch the user's settings.
    static var persist = true

    @Published var activeID: String? { didSet { if Self.persist { UserDefaults.standard.set(activeID, forKey: "active") } } }
    @Published var size: Double { didSet { if Self.persist { UserDefaults.standard.set(size, forKey: "size"); scheduleSizeApply() } } }
    @Published var favorites: Set<String> { didSet { if Self.persist { UserDefaults.standard.set(Array(favorites), forKey: "favorites") } } }
    @Published var custom: [CursorTheme] { didSet { if Self.persist { ThemeStore.saveCustom(custom) } } }
    @Published var page: Page = .browse { didSet { if oldValue == .create, page != .create { endLiveTry() } } }
    @Published var section: Section = .all
    @Published var search = ""
    @Published var applying = false
    @Published var showStates = false
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var toast: String?

    // The maker.
    @Published var draft: CursorTheme = AppModel.newDraft() { didSet { if draft != oldValue { scheduleLiveTry() } } }
    @Published var liveTry = false { didSet { liveTry ? scheduleLiveTry() : endLiveTry() } }

    let engine = CursorEngine.shared
    private var sizeTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var liveDirty = false

    init() {
        let d = UserDefaults.standard
        activeID = d.string(forKey: "active")
        let s = d.double(forKey: "size")
        size = s == 0 ? 1 : s
        favorites = Set(d.stringArray(forKey: "favorites") ?? [])
        custom = ThemeStore.loadCustom()
    }

    var allThemes: [CursorTheme] { Catalog.themes + custom }
    var active: CursorTheme? { allThemes.first { $0.id == activeID } }

    var visibleThemes: [CursorTheme] {
        var list: [CursorTheme]
        switch section {
        case .all: list = Catalog.themes
        case .favorites: list = allThemes.filter { favorites.contains($0.id) }
        case .category(let c): list = allThemes.filter { $0.category == c }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = allThemes.filter {
                $0.name.lowercased().contains(q) || $0.category.title.contains(q) || $0.style.finish.title.contains(q) || $0.style.shape.title.contains(q)
            }
        }
        return list
    }

    func count(_ s: Section) -> Int {
        switch s {
        case .all: return Catalog.themes.count
        case .favorites: return favorites.count
        case .category(let c): return allThemes.filter { $0.category == c }.count
        }
    }

    // MARK: Wearing

    func apply(_ theme: CursorTheme) {
        withAnimation(DS.softSpring) { activeID = theme.id }
        applying = true
        engine.applyAsync(theme.style, userScale: size) { [weak self] ok in
            guard let self else { return }
            self.applying = false
            self.flash(ok ? "\(theme.name.lowercased()) is on" : "macOS refused the cursor, try again")
            if ok, Self.persist, !UserDefaults.standard.bool(forKey: "askedLogin") {
                UserDefaults.standard.set(true, forKey: "askedLogin")
                self.setLaunchAtLogin(true)
            }
        }
    }

    func restore() {
        withAnimation(DS.softSpring) { activeID = nil }
        engine.restoreAsync { [weak self] in self?.flash("back to the macOS cursor") }
    }

    func reapplySaved() {
        guard let t = active else { return }
        engine.applyAsync(t.style, userScale: size)
    }

    func toggleFavorite(_ t: CursorTheme) {
        withAnimation(DS.spring) {
            if favorites.contains(t.id) { favorites.remove(t.id) } else { favorites.insert(t.id) }
        }
    }

    func shuffle() {
        if let t = Catalog.themes.filter({ $0.id != activeID }).randomElement() { apply(t) }
    }

    // MARK: Making

    static func newDraft(from base: CursorTheme? = nil) -> CursorTheme {
        var t = base ?? CursorTheme(id: "", name: "", category: .custom, style: CursorStyle())
        let own = t.category == .custom && !t.id.isEmpty
        if !own {
            t.id = "custom.\(UUID().uuidString.prefix(8).lowercased())"
            t.name = base.map { "\($0.name.lowercased()) remix" } ?? "my cursor"
            t.category = .custom
        }
        return t
    }

    /// Opens the maker, starting from a look (remix) or from scratch.
    func startCreate(from base: CursorTheme? = nil) {
        draft = Self.newDraft(from: base)
        withAnimation(DS.softSpring) { page = .create }
    }

    var draftIsSaved: Bool { custom.contains { $0.id == draft.id && $0 == draft } }

    func saveDraft(andWear wear: Bool) {
        var t = draft
        if t.name.trimmingCharacters(in: .whitespaces).isEmpty { t.name = "my cursor" }
        if let i = custom.firstIndex(where: { $0.id == t.id }) { custom[i] = t } else { custom.append(t) }
        draft = t
        if wear {
            liveDirty = false
            apply(t)
        } else {
            flash("saved to mine")
        }
    }

    func deleteCustom(_ t: CursorTheme) {
        withAnimation(DS.spring) { custom.removeAll { $0.id == t.id } }
        if activeID == t.id { restore() }
    }

    func surprise() {
        var s = CursorStyle()
        let bodies: [ArrowShape] = [.classic, .round, .chunky, .sleek, .needle, .dart, .triangle, .pin, .dot, .ring]
        s.shape = bodies.randomElement()!
        if Bool.random() {
            s.fill = [RGBA((Catalog.colors + Catalog.pastels).randomElement()!.1)]
        } else {
            s.fill = Catalog.gradients.randomElement()!.1.map { RGBA($0) }
        }
        let finishes: [Finish] = [.flat, .flat, .gloss, .gloss, .bevel, .chrome, .holo, .stripes, .dots, .glitter, .carbon, .hollow]
        s.finish = finishes.randomElement()!
        s.angle = [90, 120, 45, 135].randomElement()!
        s.accent = s.fill[0].luminance > 0.75 ? s.fill[0].mix(.black, 0.4) : s.fill[0]
        let lum = s.fill.map(\.luminance).reduce(0, +) / Double(s.fill.count)
        s.outline = lum > 0.7 ? RGBA(0x1d1d1f) : .white
        s.outlineWidth = lum > 0.7 ? 1.1 : 1.3
        if Int.random(in: 0..<6) == 0 { s.glow = s.fill[0].alpha(0.9); s.shadow = 0 }
        if Int.random(in: 0..<7) == 0 { s.motion = [.hue, .pulse, .shimmer, .breathe].randomElement()! }
        withAnimation(DS.spring) { draft.style = s }
    }

    // MARK: Live try

    /// While "try it live" is on, the maker's draft is worn system-wide as you tweak.
    private func scheduleLiveTry() {
        guard liveTry, page == .create else { return }
        liveTask?.cancel()
        liveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled, let self else { return }
            self.liveDirty = true
            self.engine.applyAsync(self.draft.style, userScale: self.size)
        }
    }

    /// Leaving the maker puts back whatever you were actually wearing.
    private func endLiveTry() {
        liveTask?.cancel()
        guard liveDirty else { return }
        liveDirty = false
        if let t = active { engine.applyAsync(t.style, userScale: size) } else { engine.restoreAsync() }
    }

    // MARK: Settings

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("CursorSpaceX: login item change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func scheduleSizeApply() {
        sizeTask?.cancel()
        sizeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled, let self, let t = self.active else { return }
            self.engine.applyAsync(t.style, userScale: self.size)
        }
    }

    func flash(_ text: String) {
        withAnimation(DS.spring) { toast = text }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            await MainActor.run {
                guard let self, self.toast == text else { return }
                withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
            }
        }
    }
}

/// Rendered cursor previews, so scrolling and tweaking never redraw the same art twice.
final class PreviewCache {
    static let shared = PreviewCache()
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 6000
        return c
    }()

    func image(_ theme: CursorTheme, _ glyph: Glyph, frame: Int = 0, k: Double = 1) -> NSImage {
        image(style: theme.style, glyph, frame: frame, k: k)
    }

    func image(style: CursorStyle, _ glyph: Glyph, frame: Int = 0, k: Double = 1) -> NSImage {
        let key = "\(style.hashValue)|\(glyph)|\(frame)|\(k)" as NSString
        if let img = cache.object(forKey: key) { return img }
        let lay = CursorPainter.layout(glyph, style)
        let kk = k * style.scale
        let cg = CursorPainter.image(glyph, style: style, k: kk, px: 2, frame: frame)
        let img = cg.map { NSImage(cgImage: $0, size: NSSize(width: lay.canvas.width * kk, height: lay.canvas.height * kk)) } ?? NSImage()
        cache.setObject(img, forKey: key)
        return img
    }

    func hotspot(_ theme: CursorTheme, _ glyph: Glyph) -> UnitPoint { hotspot(style: theme.style, glyph) }

    func hotspot(style: CursorStyle, _ glyph: Glyph) -> UnitPoint {
        let lay = CursorPainter.layout(glyph, style)
        return UnitPoint(x: lay.hotspot.x / lay.canvas.width, y: lay.hotspot.y / lay.canvas.height)
    }
}
