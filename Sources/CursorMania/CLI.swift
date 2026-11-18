import AppKit
import ServiceManagement

enum CLI {
    static func value(_ args: [String], _ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func theme(_ id: String) -> CursorTheme? {
        (Catalog.themes + ThemeStore.loadCustom()).first { $0.id == id || $0.name.lowercased() == id.lowercased() }
    }

    static func run(_ args: [String]) -> Int32 {
        // A real app connection to WindowServer, so the refresh reaches the screen.
        _ = NSApplication.shared
        switch args[0] {
        case "--list":
            for t in Catalog.themes { print("\(t.id)\t\(t.name)") }
            return 0
        case "--render-catalog":
            // One sheet per category: each row is a theme, each column a cursor state.
            let dir = URL(fileURLWithPath: value(args, "--render-catalog") ?? "catalog")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for cat in ThemeCategory.allCases {
                let themes = Catalog.themes.filter { $0.category == cat }
                if themes.isEmpty { continue }
                let roles = CursorRole.all
                let cell: CGFloat = 92, label: CGFloat = 150
                let w = Int(label + cell * CGFloat(roles.count)), h = Int(cell * CGFloat(themes.count))
                guard let ctx = CursorPainter.makeContext(w, h) else { return 1 }
                for (row, t) in themes.enumerated() {
                    let y = CGFloat(h) - cell * CGFloat(row + 1)
                    ctx.setFillColor(row.isMultiple(of: 2) ? CGColor(gray: 0.96, alpha: 1) : CGColor(gray: 0.86, alpha: 1))
                    ctx.fill(CGRect(x: 0, y: y, width: CGFloat(w), height: cell))
                    let str = NSAttributedString(string: t.name, attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .semibold)])
                    ctx.textPosition = CGPoint(x: 10, y: y + cell / 2 - 6)
                    CTLineDraw(CTLineCreateWithAttributedString(str), ctx)
                    for (col, role) in roles.enumerated() {
                        let frame = CursorPainter.isAnimated(role.glyph, t.style) ? 5 : 0
                        guard let img = CursorPainter.image(role.glyph, style: t.style, k: 1, px: 2, frame: frame) else { continue }
                        let lay = CursorPainter.layout(role.glyph, t.style)
                        let x = label + cell * CGFloat(col) + (cell - CGFloat(img.width)) / 2
                        let iy = y + (cell - CGFloat(img.height)) / 2
                        ctx.draw(img, in: CGRect(x: x, y: iy, width: CGFloat(img.width), height: CGFloat(img.height)))
                        // Hotspot marker.
                        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.9))
                        ctx.fill(CGRect(x: x + lay.hotspot.x * 2 - 1.5, y: iy + CGFloat(img.height) - lay.hotspot.y * 2 - 1.5, width: 3, height: 3))
                    }
                }
                if let img = ctx.makeImage(), let data = CursorEngine.png(img) {
                    try? data.write(to: dir.appendingPathComponent("\(cat.rawValue).png"))
                }
            }
            print("wrote \(dir.path)")
            return 0
        case "--apply":
            guard let id = value(args, "--apply"), let t = theme(id) else { print("unknown theme"); return 2 }
            let size = Double(value(args, "--size") ?? "1") ?? 1
            let ok = CursorEngine.shared.apply(t.style, userScale: size)
            print(ok ? "applied \(t.name)" : "apply failed")
            print(CursorEngine.shared.describe("com.apple.coregraphics.Arrow"))
            return ok ? 0 : 1
        case "--restore":
            CursorEngine.shared.restoreSystem()
            print("restored")
            print(CursorEngine.shared.describe("com.apple.coregraphics.Arrow"))
            return 0
        case "--uninstall-cleanup":
            // Used by `install.sh uninstall`: stock cursor back, login item off.
            CursorEngine.shared.restoreSystem()
            try? SMAppService.mainApp.unregister()
            print("cleaned up")
            return 0
        case "--verify":
            print("private API available: \(CGSCursorAPI.shared.isAvailable)")
            for n in ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.coregraphics.IBeam", "com.apple.cursor.13", "com.apple.coregraphics.Wait"] {
                print(CursorEngine.shared.describe(n))
            }
            return 0
        default:
            return MainActor.assumeIsolated { UIRender.run(args) }
        }
    }
}
