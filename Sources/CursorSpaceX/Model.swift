import AppKit
import SwiftUI
import ServiceManagement

/// Saved settings and custom themes.
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
    @Published var favorites: Set<String> { didSet { UserDefaults.standard.set(Array(favorites), forKey: "favorites") } }
    @Published var custom: [CursorTheme] { didSet { ThemeStore.saveCustom(custom) } }
    @Published var section: Section = .all
    @Published var search = ""
    @Published var applying = false
    @Published var builderOpen = false
    @Published var editing: CursorTheme?
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var toast: String?

    let engine = CursorEngine.shared
    private var sizeTask: Task<Void, Never>?

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
        case .all: list = allThemes
        case .favorites: list = allThemes.filter { favorites.contains($0.id) }
        case .category(let c): list = allThemes.filter { $0.category == c }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { list = list.filter { $0.name.lowercased().contains(q) || $0.category.title.contains(q) } }
        return list
    }

    func count(_ s: Section) -> Int {
        switch s {
        case .all: return allThemes.count
        case .favorites: return favorites.count
        case .category(let c): return allThemes.filter { $0.category == c }.count
        }
    }

    // MARK: Actions

    func apply(_ theme: CursorTheme) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { activeID = theme.id }
        applying = true
        engine.applyAsync(theme.style, userScale: size) { [weak self] ok in
            guard let self else { return }
            self.applying = false
            self.flash(ok ? "\(theme.name.lowercased()) is on" : "macOS refused the cursor, try again")
            if ok, !UserDefaults.standard.bool(forKey: "askedLogin") {
                UserDefaults.standard.set(true, forKey: "askedLogin")
                self.setLaunchAtLogin(true)
            }
        }
    }

    func restore() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { activeID = nil }
        engine.restoreAsync { [weak self] in self?.flash("back to the macOS cursor") }
    }

    func reapplySaved() {
        guard let t = active else { return }
        engine.applyAsync(t.style, userScale: size)
    }

    func toggleFavorite(_ t: CursorTheme) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if favorites.contains(t.id) { favorites.remove(t.id) } else { favorites.insert(t.id) }
        }
    }

    func shuffle() {
        if let t = allThemes.filter({ $0.id != activeID }).randomElement() { apply(t) }
    }

    func saveCustom(_ t: CursorTheme) {
        if let i = custom.firstIndex(where: { $0.id == t.id }) { custom[i] = t } else { custom.append(t) }
        PreviewCache.shared.forget(t.id)
        apply(t)
    }

    func deleteCustom(_ t: CursorTheme) {
        custom.removeAll { $0.id == t.id }
        if activeID == t.id { restore() }
    }

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
        PreviewCache.shared.clearSized()
        sizeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled, let self, let t = self.active else { return }
            self.engine.applyAsync(t.style, userScale: self.size)
        }
    }

    func flash(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            await MainActor.run {
                guard let self, self.toast == text else { return }
                withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
            }
        }
    }
}

/// Rendered cursor previews, so scrolling the gallery never redraws artwork.
final class PreviewCache {
    static let shared = PreviewCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(_ theme: CursorTheme, _ glyph: Glyph, frame: Int = 0, k: Double = 1) -> NSImage {
        let key = "\(theme.id)|\(glyph)|\(frame)|\(k)|\(theme.style.hashValue)" as NSString
        if let img = cache.object(forKey: key) { return img }
        let lay = CursorPainter.layout(glyph, theme.style)
        let kk = k * theme.style.scale
        let cg = CursorPainter.image(glyph, style: theme.style, k: kk, px: 2, frame: frame)
        let img = cg.map { NSImage(cgImage: $0, size: NSSize(width: lay.canvas.width * kk, height: lay.canvas.height * kk)) } ?? NSImage()
        cache.setObject(img, forKey: key)
        return img
    }

    func hotspot(_ theme: CursorTheme, _ glyph: Glyph) -> UnitPoint {
        let lay = CursorPainter.layout(glyph, theme.style)
        return UnitPoint(x: lay.hotspot.x / lay.canvas.width, y: lay.hotspot.y / lay.canvas.height)
    }

    func forget(_ id: String) { cache.removeAllObjects() }
    func clearSized() {}
}
