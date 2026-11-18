import SwiftUI
import AppKit

/// Headless renders for testing and for the website: nothing appears on screen.
enum UIRender {
    @MainActor
    static func run(_ args: [String]) -> Int32 {
        _ = NSApplication.shared
        AppModel.persist = false
        switch args[0] {
        case "--shot-window":
            // A real window, placed below the desktop so it never shows over anything.
            // The shell captures it with `screencapture -l <id>`; see Tools/shot.sh.
            let model = AppModel.shared
            if let id = CLI.value(args, "--theme") { model.activeID = id }
            let w = Double(CLI.value(args, "--width") ?? "1180") ?? 1180
            let h = Double(CLI.value(args, "--height") ?? "820") ?? 820
            NSApp.setActivationPolicy(.accessory)
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                               backing: .buffered, defer: false)
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: MainView().environmentObject(model))
            win.orderFrontRegardless()
            print(win.windowNumber)
            fflush(stdout)
            RunLoop.main.run(until: Date().addingTimeInterval(Double(CLI.value(args, "--hold") ?? "6") ?? 6))
            return 0
        case "--render-ui":
            let out = CLI.value(args, "--render-ui") ?? "ui.png"
            let model = AppModel.shared
            if let id = CLI.value(args, "--theme") { model.activeID = id }
            if let s = CLI.value(args, "--section") {
                model.section = s == "all" ? .all : (ThemeCategory(rawValue: s).map { .category($0) } ?? .all)
            }
            let width = Double(CLI.value(args, "--width") ?? "1180") ?? 1180
            let view = MainView(renderMode: true).environmentObject(model).frame(width: width)
            return write(view, to: out, scale: 2) ? 0 : 1
        case "--render-icon":
            let out = CLI.value(args, "--render-icon") ?? "icon.png"
            return write(IconArt().frame(width: 1024, height: 1024), to: out, scale: 1) ? 0 : 1
        case "--render-states":
            // A theme's full set on its own, for the website.
            let out = CLI.value(args, "--render-states") ?? "states.png"
            guard let t = CLI.theme(CLI.value(args, "--theme") ?? "essentials.graphite") else { return 2 }
            let view = MacWindow(title: "\(t.name.lowercased()).cape") { StatesBoard(theme: t) }.frame(width: 760).padding(30)
            return write(view, to: out, scale: 2) ? 0 : 1
        case "--render-sprites":
            // Cursor images for the website: a 2x picture of each look, plus 1x/2x
            // arrow and hand files the page uses as a real CSS cursor, and looks.json.
            let dir = URL(fileURLWithPath: CLI.value(args, "--render-sprites") ?? "sprites")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var meta: [[String: Any]] = []
            func save(_ img: CGImage?, _ name: String) { if let img, let d = CursorEngine.png(img) { try? d.write(to: dir.appendingPathComponent(name)) } }
            for t in Catalog.themes {
                let slug = t.id.replacingOccurrences(of: ".", with: "-")
                let k = t.style.scale
                for (name, g) in [("arrow", Glyph.arrow), ("hand", .pointing), ("ibeam", .ibeam), ("wait", .wait), ("grab", .closedHand)] {
                    save(CursorPainter.image(g, style: t.style, k: 1, px: 4, frame: 4), "\(slug)-\(name)@4x.png")
                }
                for (name, g) in [("arrow", Glyph.arrow), ("hand", .pointing), ("ibeam", .ibeam)] {
                    save(CursorPainter.image(g, style: t.style, k: k, px: 1), "\(slug)-\(name)-c1.png")
                    save(CursorPainter.image(g, style: t.style, k: k, px: 2), "\(slug)-\(name)-c2.png")
                }
                func hs(_ g: Glyph) -> [Double] { let l = CursorPainter.layout(g, t.style); return [Double(l.hotspot.x * k).rounded(), Double(l.hotspot.y * k).rounded()] }
                func sz(_ g: Glyph) -> [Double] { let l = CursorPainter.layout(g, t.style); return [Double(l.canvas.width), Double(l.canvas.height)] }
                meta.append(["id": slug, "name": t.name.lowercased(), "category": t.category.title, "dark": t.style.glow != nil || t.category == .neon,
                             "arrowHot": hs(.arrow), "handHot": hs(.pointing), "ibeamHot": hs(.ibeam),
                             "arrowSize": sz(.arrow), "handSize": sz(.pointing), "ibeamSize": sz(.ibeam), "waitSize": sz(.wait), "grabSize": sz(.closedHand),
                             "pixel": t.style.shape == .pixel])
            }
            let data = try! JSONSerialization.data(withJSONObject: meta, options: [.sortedKeys])
            try? data.write(to: dir.appendingPathComponent("looks.json"))
            print("wrote \(meta.count) looks to \(dir.path)")
            return 0
        default:
            print("""
            cursorspacex command line:
              --list                       every built-in theme id
              --apply <id> [--size 1.2]    wear a theme system-wide
              --restore                    back to the stock macOS cursor
              --verify                     what WindowServer holds right now
              --render-catalog <dir>       every state of every theme as PNG sheets
              --render-ui <png>            the app window, rendered offscreen
              --render-icon <png>          the app icon
            """)
            return 2
        }
    }

    @MainActor
    static func write<V: View>(_ view: V, to path: String, scale: CGFloat) -> Bool {
        let r = ImageRenderer(content: view.environment(\.colorScheme, .light))
        r.scale = scale
        guard let cg = r.cgImage, let data = CursorEngine.png(cg) else { print("render failed"); return false }
        do { try data.write(to: URL(fileURLWithPath: path)); print("wrote \(path) \(cg.width)x\(cg.height)"); return true } catch { return false }
    }
}

/// The app icon: a glossy aqua squircle with a big graphite pointer.
struct IconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 0.93, green: 0.96, blue: 1), location: 0),
                    .init(color: Color(red: 0.72, green: 0.84, blue: 1), location: 0.5),
                    .init(color: Color(red: 0.55, green: 0.76, blue: 0.98), location: 1),
                ], startPoint: .top, endPoint: .bottom))
            DotGrid(spacing: 46, color: .white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 230, style: .continuous))
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0)], startPoint: .top, endPoint: .center))
                .padding(.horizontal, 60).padding(.top, 18).padding(.bottom, 520)
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .strokeBorder(Color(red: 0.13, green: 0.09, blue: 0.6).opacity(0.55), lineWidth: 6)
            let t = Catalog.themes[0]
            let arrow = CursorPainter.image(.arrow, style: t.style, k: 1, px: 22)!
            Image(decorative: arrow, scale: 1)
                .resizable()
                .frame(width: 34 * 19, height: 42 * 19)
                .offset(x: 110, y: 120)
            let neon = Catalog.themes.first { $0.id == "neon.neon-pink" }!
            let hand = CursorPainter.image(.pointing, style: neon.style, k: 1, px: 10)!
            Image(decorative: hand, scale: 1).resizable().frame(width: 34 * 6.5, height: 34 * 6.5)
                .offset(x: -250, y: -230)
                .opacity(0.95)
        }
        .frame(width: 1024, height: 1024)
        .padding(0)
    }
}
