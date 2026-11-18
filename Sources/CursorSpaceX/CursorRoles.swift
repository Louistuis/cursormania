import CoreGraphics

/// A compass direction for the resize cursors.
enum Compass: String, Hashable, Codable {
    case e, w, n, s, ne, nw, se, sw
    /// Angle in degrees in a y-down space (0 points right, 90 points down).
    var angle: Double {
        switch self {
        case .e: return 0
        case .se: return 45
        case .s: return 90
        case .sw: return 135
        case .w: return 180
        case .nw: return 225
        case .n: return 270
        case .ne: return 315
        }
    }
}

/// What gets drawn for a role.
enum Glyph: Hashable {
    case arrow, contextMenu, help, busy, wait
    case ibeam, ibeamHorizontal
    case pointing, openHand, closedHand, countUp, countDown, countUpDown
    case copy, alias, move, forbidden, poof
    case crosshair, crosshairThin, cell, camera, cameraAlt, zoomIn, zoomOut
    case resize(Compass, both: Bool)
    case resizeSquare
}

enum RoleGroup: String, CaseIterable, Identifiable {
    case basics, text, hands, drag, precision, resize
    var id: String { rawValue }
    var title: String {
        switch self {
        case .basics: return "pointer"
        case .text: return "text"
        case .hands: return "links & hands"
        case .drag: return "drag & drop"
        case .precision: return "precision"
        case .resize: return "resize"
        }
    }
}

/// Every cursor state macOS 26 asks WindowServer for, with the names it is
/// registered under. Several names can share one drawing (Tahoe added "S"
/// variants for the arrow and I-beam, and browsers ask for cursor.0 / cursor.1).
struct CursorRole: Identifiable, Hashable {
    let id: String
    let title: String
    let group: RoleGroup
    let glyph: Glyph
    let names: [String]

    static func cg(_ n: String) -> String { "com.apple.coregraphics.\(n)" }
    static func c(_ i: Int) -> String { "com.apple.cursor.\(i)" }

    static let all: [CursorRole] = [
        .init(id: "arrow", title: "arrow", group: .basics, glyph: .arrow, names: [cg("Arrow"), cg("ArrowS"), c(0)]),
        .init(id: "context", title: "context menu", group: .basics, glyph: .contextMenu, names: [cg("ArrowCtx"), c(24)]),
        .init(id: "help", title: "help", group: .basics, glyph: .help, names: [c(40)]),
        .init(id: "busy", title: "busy, still clickable", group: .basics, glyph: .busy, names: [c(4)]),
        .init(id: "wait", title: "wait (beachball)", group: .basics, glyph: .wait, names: [cg("Wait")]),

        .init(id: "ibeam", title: "text", group: .text, glyph: .ibeam, names: [cg("IBeam"), cg("IBeamS"), c(1), cg("IBeamXOR")]),
        .init(id: "ibeamH", title: "vertical text", group: .text, glyph: .ibeamHorizontal, names: [c(26)]),

        .init(id: "pointing", title: "link", group: .hands, glyph: .pointing, names: [c(13), c(2)]),
        .init(id: "open", title: "open hand", group: .hands, glyph: .openHand, names: [c(12)]),
        .init(id: "closed", title: "grab", group: .hands, glyph: .closedHand, names: [c(11)]),
        .init(id: "countUp", title: "counting up", group: .hands, glyph: .countUp, names: [c(14)]),
        .init(id: "countDown", title: "counting down", group: .hands, glyph: .countDown, names: [c(15)]),
        .init(id: "countUpDown", title: "counting up/down", group: .hands, glyph: .countUpDown, names: [c(16)]),

        .init(id: "copy", title: "copy", group: .drag, glyph: .copy, names: [cg("Copy"), c(5)]),
        .init(id: "alias", title: "make alias", group: .drag, glyph: .alias, names: [cg("Alias")]),
        .init(id: "move", title: "move", group: .drag, glyph: .move, names: [cg("Move")]),
        .init(id: "forbidden", title: "not allowed", group: .drag, glyph: .forbidden, names: [c(3)]),
        .init(id: "poof", title: "poof", group: .drag, glyph: .poof, names: [c(25)]),

        .init(id: "cross", title: "crosshair", group: .precision, glyph: .crosshair, names: [c(7)]),
        .init(id: "cross2", title: "crosshair thin", group: .precision, glyph: .crosshairThin, names: [c(8)]),
        .init(id: "cell", title: "cell", group: .precision, glyph: .cell, names: [c(41), c(20)]),
        .init(id: "camera", title: "screenshot", group: .precision, glyph: .camera, names: [c(10)]),
        .init(id: "camera2", title: "screenshot window", group: .precision, glyph: .cameraAlt, names: [c(9)]),
        .init(id: "zoomIn", title: "zoom in", group: .precision, glyph: .zoomIn, names: [c(42)]),
        .init(id: "zoomOut", title: "zoom out", group: .precision, glyph: .zoomOut, names: [c(43)]),

        .init(id: "rEW", title: "resize left/right", group: .resize, glyph: .resize(.e, both: true), names: [c(19), c(28)]),
        .init(id: "rNS", title: "resize up/down", group: .resize, glyph: .resize(.n, both: true), names: [c(23), c(32)]),
        .init(id: "rNESW", title: "resize diagonal", group: .resize, glyph: .resize(.ne, both: true), names: [c(30)]),
        .init(id: "rNWSE", title: "resize diagonal", group: .resize, glyph: .resize(.nw, both: true), names: [c(34)]),
        .init(id: "rW", title: "resize left", group: .resize, glyph: .resize(.w, both: false), names: [c(17), c(38)]),
        .init(id: "rE", title: "resize right", group: .resize, glyph: .resize(.e, both: false), names: [c(18), c(27)]),
        .init(id: "rN", title: "resize up", group: .resize, glyph: .resize(.n, both: false), names: [c(21), c(31)]),
        .init(id: "rS", title: "resize down", group: .resize, glyph: .resize(.s, both: false), names: [c(22), c(36)]),
        .init(id: "rNE", title: "resize up-right", group: .resize, glyph: .resize(.ne, both: false), names: [c(29)]),
        .init(id: "rNW", title: "resize up-left", group: .resize, glyph: .resize(.nw, both: false), names: [c(33)]),
        .init(id: "rSE", title: "resize down-right", group: .resize, glyph: .resize(.se, both: false), names: [c(35)]),
        .init(id: "rSW", title: "resize down-left", group: .resize, glyph: .resize(.sw, both: false), names: [c(37)]),
        .init(id: "rSquare", title: "resize any way", group: .resize, glyph: .resizeSquare, names: [c(39)]),
    ]

    static func role(_ id: String) -> CursorRole { all.first { $0.id == id }! }

    /// Every name the system registers that CursorSpaceX may touch. Used to save
    /// the original cursors before the first theme goes on.
    static var everyName: [String] {
        var names = Set(all.flatMap(\.names))
        for i in 0...45 { names.insert(c(i)) }
        for n in ["Arrow", "ArrowS", "IBeam", "IBeamS", "IBeamXOR", "Alias", "Copy", "Move", "ArrowCtx", "Wait", "Empty"] { names.insert(cg(n)) }
        return names.sorted()
    }
}
