import Foundation

/// The built-in looks. Each one is a complete set: every cursor state is drawn
/// from the same style.
enum Catalog {
    static let themes: [CursorTheme] = build()

    private static func t(_ name: String, _ cat: ThemeCategory, _ make: (inout CursorStyle) -> Void) -> CursorTheme {
        var s = CursorStyle()
        make(&s)
        let id = cat.rawValue + "." + name.lowercased().replacingOccurrences(of: " ", with: "-")
        return CursorTheme(id: id, name: name, category: cat, style: s)
    }

    private static func build() -> [CursorTheme] {
        var all: [CursorTheme] = []

        // Essentials: quiet, Mac-like.
        all += [
            t("Graphite", .essentials) { _ in },
            t("Snow", .essentials) { $0.fill = [.white]; $0.outline = .black; $0.outlineWidth = 1.1 },
            t("Midnight", .essentials) { $0.fill = [RGBA(0x1c2a4a)]; $0.accent = RGBA(0x5e8bff) },
            t("Slate", .essentials) { $0.fill = [RGBA(0x5b6472)] },
            t("Ink", .essentials) { $0.shape = .sleek; $0.fill = [RGBA(0x111111)] },
            t("Paper", .essentials) { $0.shape = .sleek; $0.fill = [RGBA(0xfafafa)]; $0.outline = RGBA(0x1a1a1a); $0.outlineWidth = 1.1 },
            t("Espresso", .essentials) { $0.shape = .sleek; $0.fill = [RGBA(0x3b2a20)]; $0.outline = RGBA(0xf6efe7); $0.accent = RGBA(0xc8875a) },
            t("Dart", .essentials) { $0.shape = .dart; $0.fill = [RGBA(0x1d1d1f)] },
            t("Dart White", .essentials) { $0.shape = .dart; $0.fill = [.white]; $0.outline = RGBA(0x1d1d1f); $0.outlineWidth = 1.1 },
        ]

        // Color pop: one bright colour, white rim.
        let pops: [(String, UInt32)] = [("Tangerine", 0xff8a00), ("Lime", 0x7ed321), ("Bubblegum", 0xff5fa2), ("Ocean", 0x0a84ff),
                                        ("Grape", 0x8e44ff), ("Lemon", 0xffd60a), ("Cherry", 0xe5243b), ("Mint", 0x2fd6a3),
                                        ("Sky", 0x5ac8fa), ("Coral", 0xff6f61), ("Teal", 0x0fb5ae), ("Indigo", 0x4b4bf0)]
        for (i, p) in pops.enumerated() {
            all.append(t(p.0, .pop) {
                $0.shape = i.isMultiple(of: 2) ? .sleek : .classic
                $0.fill = [RGBA(p.1)]
                $0.accent = RGBA(p.1)
                if RGBA(p.1).luminance > 0.75 { $0.outline = RGBA(0x1d1d1f); $0.outlineWidth = 1.1 }
            })
        }

        // Gradients.
        let grads: [(String, [UInt32], Double)] = [
            ("Sunset", [0xffb347, 0xff5e62, 0xc33ea0], 90), ("Aurora", [0x43e97b, 0x38f9d7, 0x7f5cff], 120),
            ("Peach", [0xffd3a5, 0xfd6585], 90), ("Blue Hour", [0x5ee7ff, 0x2a5bff, 0x1b1f6b], 90),
            ("Lavender Haze", [0xe0c3fc, 0x8ec5fc], 60), ("Fire", [0xffe259, 0xff7a00, 0xe52d27], 90),
            ("Tropic", [0x00f5a0, 0x00d9f5], 90), ("Cotton Candy", [0xffc3e1, 0xa1c4fd], 45),
            ("Dusk", [0x41295a, 0x2f0743, 0xff6a88], 90), ("Lagoon", [0x0f2027, 0x2c9fa8, 0x9df0e0], 90),
        ]
        for (i, g) in grads.enumerated() {
            all.append(t(g.0, .gradient) {
                $0.shape = [.sleek, .classic, .dart][i % 3]
                $0.fill = g.1.map { RGBA($0) }
                $0.angle = g.2
                $0.accent = RGBA(g.1[g.1.count / 2])
                if $0.fill.allSatisfy({ $0.luminance > 0.7 }) { $0.outline = RGBA(0x2a2a2a); $0.outlineWidth = 1.0 }
            })
        }

        // Neon: dark core, coloured rim and glow.
        let neons: [(String, UInt32, UInt32?)] = [("Neon Cyan", 0x00f0ff, nil), ("Neon Pink", 0xff2bd6, nil), ("Neon Lime", 0xb6ff00, nil),
                                                  ("Neon Violet", 0x9d4dff, nil), ("Neon Orange", 0xff7b00, nil), ("Laser Red", 0xff1f3d, nil),
                                                  ("Synthwave", 0xff2bd6, 0x00e5ff), ("Electric", 0x2f6bff, 0x00f0ff)]
        for (i, n) in neons.enumerated() {
            all.append(t(n.0, .neon) {
                $0.shape = i.isMultiple(of: 2) ? .sleek : .classic
                $0.fill = [RGBA(0x0b0b14)]
                $0.outline = RGBA(n.1)
                $0.outlineWidth = 1.5
                $0.glow = RGBA(n.2 ?? n.1, 0.95)
                $0.glowRadius = 6
                $0.shadow = 0
                $0.accent = RGBA(n.1)
                if let second = n.2 { $0.fill = [RGBA(n.1, 0.9), RGBA(second, 0.9)]; $0.outline = RGBA(0x0b0b14); $0.outlineWidth = 1.2 }
            })
        }

        // Glass: see-through fill, bright rim, soft highlight.
        let glass: [(String, UInt32, Double)] = [("Frosted", 0xffffff, 0.42), ("Ice", 0xbfe9ff, 0.5), ("Rose Glass", 0xffb3c7, 0.5),
                                                 ("Smoke", 0x2b2b30, 0.55), ("Aqua", 0x4fd1ff, 0.55), ("Amber Glass", 0xffc061, 0.55)]
        for (i, g) in glass.enumerated() {
            all.append(t(g.0, .glass) {
                $0.shape = i.isMultiple(of: 2) ? .sleek : .dart
                $0.fill = [RGBA(g.1, g.2 + 0.2), RGBA(g.1, g.2 - 0.15)]
                $0.outline = g.1 == 0x2b2b30 ? RGBA(1, 1, 1, 0.85) : RGBA(0x1d1d1f, 0.55)
                $0.outlineWidth = 1.0
                $0.gloss = true
                $0.shadow = 0.28
                $0.accent = RGBA(g.1 == 0xffffff ? 0x0a84ff : g.1)
            })
        }

        // Metal: multi-stop gradients that read as polished.
        let metals: [(String, [UInt32])] = [("Gold", [0xfff1b8, 0xe6b84a, 0x9c6b12, 0xf5d77a]), ("Rose Gold", [0xffe0d6, 0xe8a598, 0xa9665a, 0xf3c2b5]),
                                            ("Silver", [0xffffff, 0xc9ccd1, 0x7c828a, 0xe8eaed]), ("Bronze", [0xf3c38b, 0xb87333, 0x6b3d17, 0xd8955a]),
                                            ("Titanium", [0xd9dcd6, 0x8a8f8c, 0x45494a, 0xb7bbb6]), ("Space Black", [0x5a5a5e, 0x2a2a2d, 0x0c0c0d, 0x3c3c40])]
        for (i, m) in metals.enumerated() {
            all.append(t(m.0, .metal) {
                $0.shape = i.isMultiple(of: 2) ? .classic : .sleek
                $0.fill = m.1.map { RGBA($0) }
                $0.angle = 70
                $0.gloss = true
                $0.outline = m.0 == "Space Black" ? RGBA(0xd0d0d0) : RGBA(0x2a2118, 0.9)
                $0.outlineWidth = 1.0
                $0.accent = RGBA(m.1[1])
            })
        }

        // Pixel art.
        all += [
            t("Classic Pixel", .pixel) { $0.shape = .pixel; $0.scale = 1.15 },
            t("Pixel Inverse", .pixel) { $0.shape = .pixel; $0.fill = [.white]; $0.outline = .black; $0.scale = 1.15 },
            t("Handheld", .pixel) { $0.shape = .pixel; $0.fill = [RGBA(0x8bac0f)]; $0.outline = RGBA(0x0f380f); $0.accent = RGBA(0x306230); $0.scale = 1.15 },
            t("Terminal", .pixel) { $0.shape = .pixel; $0.fill = [RGBA(0x00ff66)]; $0.outline = RGBA(0x001a0a); $0.accent = RGBA(0x00cc52); $0.scale = 1.15 },
            t("Amber CRT", .pixel) { $0.shape = .pixel; $0.fill = [RGBA(0xffb000)]; $0.outline = RGBA(0x2a1600); $0.accent = RGBA(0xff8800); $0.scale = 1.15 },
            t("Pixel Pink", .pixel) { $0.shape = .pixel; $0.fill = [RGBA(0xff77c8)]; $0.outline = RGBA(0x3a0026); $0.accent = RGBA(0xff3aa6); $0.scale = 1.15 },
            t("Pixel Sky", .pixel) { $0.shape = .pixel; $0.fill = [RGBA(0x7fd4ff), RGBA(0x2a6dff)]; $0.outline = RGBA(0x061433); $0.scale = 1.15 },
        ]

        // Dots, like the iPad pointer.
        all += [
            t("Dot Graphite", .dots) { $0.shape = .dot; $0.fill = [RGBA(0x1d1d1f, 0.85)]; $0.outline = RGBA(1, 1, 1, 0.9); $0.outlineWidth = 1.2 },
            t("Dot Snow", .dots) { $0.shape = .dot; $0.fill = [RGBA(1, 1, 1, 0.92)]; $0.outline = RGBA(0, 0, 0, 0.55); $0.outlineWidth = 1 },
            t("Dot Blue", .dots) { $0.shape = .dot; $0.fill = [RGBA(0x0a84ff)]; $0.outline = .white },
            t("Dot Glass", .dots) { $0.shape = .dot; $0.fill = [RGBA(1, 1, 1, 0.55), RGBA(1, 1, 1, 0.25)]; $0.outline = RGBA(0, 0, 0, 0.45); $0.outlineWidth = 0.9; $0.gloss = true },
            t("Halo", .dots) { $0.shape = .ring; $0.fill = [RGBA(0x1d1d1f)]; $0.outline = RGBA(1, 1, 1, 0.95); $0.outlineWidth = 1 },
            t("Halo Neon", .dots) { $0.shape = .ring; $0.fill = [RGBA(0x00f0ff)]; $0.outline = RGBA(0x001018); $0.glow = RGBA(0x00f0ff, 0.9); $0.shadow = 0; $0.accent = RGBA(0x00b8ff) },
            t("Dot Sunset", .dots) { $0.shape = .dot; $0.fill = [RGBA(0xffb347), RGBA(0xff5e62)]; $0.outline = .white },
        ]

        // Animated.
        all += [
            t("Rainbow", .animated) { $0.shape = .sleek; $0.fill = [RGBA(0xff3b6b), RGBA(0xffb02e)]; $0.motion = .hue },
            t("Disco", .animated) { $0.shape = .classic; $0.fill = [RGBA(0x0b0b14)]; $0.outline = RGBA(0xff2bd6); $0.glow = RGBA(0xff2bd6, 0.95); $0.shadow = 0; $0.outlineWidth = 1.5; $0.motion = .hue },
            t("Pulse Cyan", .animated) { $0.shape = .sleek; $0.fill = [RGBA(0x0b0b14)]; $0.outline = RGBA(0x00f0ff); $0.glow = RGBA(0x00f0ff); $0.glowRadius = 6; $0.shadow = 0; $0.outlineWidth = 1.5; $0.motion = .pulse },
            t("Pulse Magenta", .animated) { $0.shape = .dart; $0.fill = [RGBA(0x1a0016)]; $0.outline = RGBA(0xff4fd8); $0.glow = RGBA(0xff4fd8); $0.glowRadius = 6; $0.shadow = 0; $0.outlineWidth = 1.5; $0.motion = .pulse },
            t("Shimmer Gold", .animated) { $0.shape = .classic; $0.fill = [RGBA(0xfff1b8), RGBA(0xe6b84a), RGBA(0x9c6b12)]; $0.outline = RGBA(0x2a2118, 0.9); $0.outlineWidth = 1; $0.motion = .shimmer },
            t("Shimmer Silver", .animated) { $0.shape = .sleek; $0.fill = [RGBA(0xffffff), RGBA(0xb9bdc4), RGBA(0x6e747c)]; $0.outline = RGBA(0x1d1d1f, 0.8); $0.outlineWidth = 1; $0.motion = .shimmer },
            t("Breathing Mint", .animated) { $0.shape = .sleek; $0.fill = [RGBA(0x2fd6a3)]; $0.motion = .breathe; $0.accent = RGBA(0x2fd6a3) },
            t("Rainbow Dot", .animated) { $0.shape = .dot; $0.fill = [RGBA(0xff3b6b), RGBA(0xffb02e)]; $0.motion = .hue },
            t("Rainbow Pixel", .animated) { $0.shape = .pixel; $0.fill = [RGBA(0xff3b6b)]; $0.motion = .hue; $0.scale = 1.15 },
        ]

        all += more()

        // Big and bold, for visibility.
        all += [
            t("XL Black", .bold) { $0.scale = 1.6; $0.outlineWidth = 1.5 },
            t("XL White", .bold) { $0.scale = 1.6; $0.fill = [.white]; $0.outline = .black; $0.outlineWidth = 1.4 },
            t("XL Hi-Vis", .bold) { $0.scale = 1.6; $0.shape = .sleek; $0.fill = [RGBA(0xffe600)]; $0.outline = .black; $0.outlineWidth = 1.6; $0.accent = RGBA(0xff7a00) },
            t("XL Magenta", .bold) { $0.scale = 1.6; $0.shape = .sleek; $0.fill = [RGBA(0xff1fa8)]; $0.outline = .white; $0.outlineWidth = 1.5 },
            t("XL Cyan", .bold) { $0.scale = 1.6; $0.fill = [RGBA(0x00d7ff)]; $0.outline = .black; $0.outlineWidth = 1.5 },
            t("XXL Black", .bold) { $0.scale = 2.1; $0.outlineWidth = 1.5 },
        ]
        return all
    }

    /// Palettes shared with the maker, so what you can build matches what ships.
    static let colors: [(String, UInt32)] = [
        ("Ruby", 0xe0115f), ("Cherry", 0xe5243b), ("Tomato", 0xff4b3e), ("Coral", 0xff6f61), ("Tangerine", 0xff8a00),
        ("Apricot", 0xffa94d), ("Marigold", 0xffc107), ("Lemon", 0xffd60a), ("Chartreuse", 0xc6f000), ("Lime", 0x7ed321),
        ("Kelly", 0x2fbf4a), ("Emerald", 0x0fa968), ("Mint", 0x2fd6a3), ("Teal", 0x0fb5ae), ("Turquoise", 0x22d3ee),
        ("Sky", 0x5ac8fa), ("Azure", 0x1e90ff), ("Ocean", 0x0a84ff), ("Cobalt", 0x0047ab), ("Navy", 0x1b2a6b),
        ("Indigo", 0x4b4bf0), ("Violet", 0x7f3cff), ("Grape", 0x8e44ff), ("Orchid", 0xc061e0), ("Magenta", 0xff1fa8),
        ("Bubblegum", 0xff5fa2), ("Rose", 0xff8fab), ("Wine", 0x7b1e3a), ("Chocolate", 0x5c3a21), ("Caramel", 0xc68642),
        ("Sand", 0xd8c3a5), ("Olive", 0x7a7d2c), ("Forest", 0x1f5c3b), ("Ash", 0x8e8e93), ("Charcoal", 0x2c2c2e), ("Ivory", 0xfffbf0),
    ]

    static let pastels: [(String, UInt32)] = [
        ("Blush", 0xffc8dd), ("Peach Milk", 0xffd6c2), ("Butter", 0xfff3b0), ("Pistachio", 0xd4f0c0), ("Seafoam", 0xb8f2e6),
        ("Baby Blue", 0xbde0fe), ("Periwinkle", 0xc3c7ff), ("Lilac", 0xe0c3fc), ("Cotton", 0xf8d7f0), ("Fog", 0xdfe3ea),
        ("Melon", 0xffb5a7), ("Matcha", 0xc9e4a6), ("Lavender", 0xd7c9ff), ("Powder", 0xcde7f0), ("Shell", 0xfbe4d8), ("Mist", 0xe8f4f2),
    ]

    static let gradients: [(String, [UInt32])] = [
        ("Sunset", [0xffb347, 0xff5e62, 0xc33ea0]), ("Aurora", [0x43e97b, 0x38f9d7, 0x7f5cff]), ("Peach", [0xffd3a5, 0xfd6585]),
        ("Blue Hour", [0x5ee7ff, 0x2a5bff, 0x1b1f6b]), ("Fire", [0xffe259, 0xff7a00, 0xe52d27]), ("Tropic", [0x00f5a0, 0x00d9f5]),
        ("Cotton Candy", [0xffc3e1, 0xa1c4fd]), ("Dusk", [0x41295a, 0xff6a88]), ("Lagoon", [0x0f2027, 0x2c9fa8, 0x9df0e0]),
        ("Mango", [0xffe000, 0xff6a00]), ("Berry", [0x8e2de2, 0xff0080]), ("Ocean Deep", [0x2e3192, 0x1bffff]),
        ("Grapefruit", [0xff9a9e, 0xfad0c4]), ("Forest Mist", [0x134e5e, 0x71b280]), ("Candy Cane", [0xff4b5c, 0xffffff]),
        ("Galaxy", [0x0f0c29, 0x302b63, 0xc471ed]),
    ]

    private static func more() -> [CursorTheme] {
        var all: [CursorTheme] = []
        let bodies: [ArrowShape] = [.round, .chunky, .sleek, .needle, .triangle, .pin, .classic, .dart]

        // Shapes: every body, in a few signature colourways.
        let showcase: [(String, UInt32, RGBA)] = [("Ink", 0x161618, .white), ("Snow", 0xffffff, RGBA(0x1d1d1f)), ("Azure", 0x1e90ff, .white), ("Coral", 0xff6f61, .white)]
        for body in [ArrowShape.round, .chunky, .needle, .triangle, .pin] {
            for (cname, hex, rim) in showcase {
                all.append(t("\(body.title.capitalized) \(cname)", .shapes) {
                    $0.shape = body; $0.fill = [RGBA(hex)]; $0.outline = rim
                    $0.outlineWidth = hex == 0xffffff ? 1.1 : 1.3; $0.accent = hex == 0xffffff || hex == 0x161618 ? RGBA(0x0a84ff) : RGBA(hex)
                })
            }
        }

        // Spectrum: a full wheel of solid colours on soft and chunky bodies.
        for (i, c) in colors.enumerated() {
            all.append(t(c.0, .spectrum) {
                $0.shape = bodies[i % 3]
                $0.fill = [RGBA(c.1)]
                $0.accent = RGBA(c.1)
                if RGBA(c.1).luminance > 0.72 { $0.outline = RGBA(0x1d1d1f); $0.outlineWidth = 1.1 }
            })
        }

        // Pastel: soft fills with a tinted rim instead of black.
        for (i, c) in pastels.enumerated() {
            all.append(t(c.0, .pastel) {
                $0.shape = [ArrowShape.round, .pin, .sleek, .triangle][i % 4]
                $0.fill = [RGBA(c.1)]
                $0.outline = RGBA(c.1).mix(.black, 0.62)
                $0.outlineWidth = 1.1
                $0.shadow = 0.25
                $0.accent = RGBA(c.1).mix(.black, 0.3)
            })
        }

        // Aqua: bevelled candy, lit from the top left.
        let aquas: [(String, [UInt32])] = [("Aqua Blue", [0x9fd3ff, 0x2a86ff]), ("Aqua Graphite", [0xd6d9de, 0x6b717c]), ("Aqua Lime", [0xd9ff9b, 0x5bc21a]),
                                           ("Aqua Tangerine", [0xffd59b, 0xff7a00]), ("Aqua Grape", [0xd9b8ff, 0x7b2cff]), ("Aqua Strawberry", [0xffb3c1, 0xff2d55]),
                                           ("Aqua Mint", [0xbdfbe6, 0x16c79a]), ("Aqua Lemon", [0xfff6a8, 0xf5c400]), ("Aqua Sky", [0xc9f1ff, 0x22aee8]),
                                           ("Aqua Rose", [0xffd6e6, 0xf06ba8]), ("Aqua Smoke", [0x8a8f98, 0x26292e]), ("Aqua Pearl", [0xffffff, 0xd8dde6])]
        for (i, a) in aquas.enumerated() {
            all.append(t(a.0, .aqua) {
                $0.shape = [ArrowShape.round, .chunky, .pin][i % 3]
                $0.fill = a.1.map { RGBA($0) }
                $0.finish = .bevel
                $0.outline = RGBA(a.1[1]).mix(.black, 0.55)
                $0.outlineWidth = 1.0
                $0.accent = RGBA(a.1[1])
            })
        }

        // Chrome and holo foil.
        let chromes: [(String, UInt32)] = [("Chrome", 0xc8ccd2), ("Gold Chrome", 0xe6b84a), ("Rose Chrome", 0xe8a598), ("Blue Chrome", 0x6aa8ff),
                                           ("Black Chrome", 0x3a3d42), ("Green Chrome", 0x4cd38a), ("Purple Chrome", 0xa784ff)]
        for (i, c) in chromes.enumerated() {
            all.append(t(c.0, .chrome) {
                $0.shape = [ArrowShape.sleek, .classic, .chunky, .needle][i % 4]
                $0.fill = [RGBA(c.1)]
                $0.finish = .chrome
                $0.outline = RGBA(c.1).mix(.black, 0.7)
                $0.outlineWidth = 0.9
                $0.accent = RGBA(c.1).mix(.black, 0.2)
            })
        }
        let holos: [(String, UInt32, ArrowShape)] = [("Holo", 0xf4f4ff, .sleek), ("Holo Pearl", 0xffffff, .round), ("Holo Night", 0x22223a, .classic),
                                                     ("Holo Pin", 0xf4f4ff, .pin), ("Holo Dot", 0xf4f4ff, .dot), ("Holo Shift", 0xf4f4ff, .chunky)]
        for h in holos {
            all.append(t(h.0, .chrome) {
                $0.shape = h.2
                $0.fill = [RGBA(h.1)]
                $0.finish = .holo
                $0.outline = h.1 == 0x22223a ? RGBA(0xd8d8ff) : RGBA(0x3a3a55, 0.85)
                $0.outlineWidth = 1.0
                $0.accent = RGBA(0xb06bff)
                if h.0 == "Holo Shift" { $0.motion = .hue }
            })
        }

        // Patterns.
        let patterns: [(String, Finish, [UInt32], RGBA)] = [
            ("Candy Stripe", .stripes, [0xff4b5c], .white), ("Mint Stripe", .stripes, [0x2fd6a3], .white), ("Navy Stripe", .stripes, [0x1b2a6b], .white),
            ("Sunny Stripe", .stripes, [0xffd60a], RGBA(0x1d1d1f)), ("Zebra", .stripes, [0xffffff], RGBA(0x1d1d1f)),
            ("Polka Red", .dots, [0xe5243b], .white), ("Polka Blue", .dots, [0x1e90ff], .white), ("Polka Pink", .dots, [0xff8fab], .white),
            ("Polka Black", .dots, [0x161618], .white), ("Polka Cream", .dots, [0xfff3d6], RGBA(0x3b2a20)),
            ("Checker", .checker, [0xffffff], RGBA(0x1d1d1f)), ("Racing", .checker, [0x161618], .white), ("Picnic", .checker, [0xe5243b], .white),
            ("Lime Check", .checker, [0x7ed321], .white),
            ("Carbon", .carbon, [0x2a2a2e], RGBA(0xd0d0d0)), ("Carbon Red", .carbon, [0x8a1020], .white), ("Carbon Blue", .carbon, [0x14306b], .white),
            ("Carbon Gold", .carbon, [0x7a5a12], RGBA(0xffe9a8)),
            ("Rainbow Stripe", .stripes, [0xff3b6b, 0xffb02e, 0x2fd6a3, 0x1e90ff, 0x8e44ff], .white),
            ("Galaxy Dots", .dots, [0x0f0c29, 0x302b63, 0xc471ed], .white),
        ]
        for (i, p) in patterns.enumerated() {
            all.append(t(p.0, .pattern) {
                $0.shape = [ArrowShape.chunky, .round, .classic, .pin][i % 4]
                $0.fill = p.2.map { RGBA($0) }
                $0.angle = 120
                $0.finish = p.1
                $0.outline = p.3
                $0.outlineWidth = 1.2
                $0.accent = RGBA(p.2[0])
            })
        }

        // Glitter.
        let glitters: [(String, [UInt32], RGBA)] = [("Disco Silver", [0xb9bdc4, 0x5d636c], RGBA(0x1d1d1f)), ("Party Gold", [0xffe082, 0xc8901a], RGBA(0x3a2a08)),
                                                    ("Pink Fizz", [0xff7ac6, 0xc2187a], .white), ("Night Sky", [0x0f0c29, 0x302b63], .white),
                                                    ("Mermaid", [0x2fd6c7, 0x6b4bff], .white), ("Ruby Slipper", [0xff2d55, 0x8a0020], .white),
                                                    ("Emerald City", [0x34e08a, 0x0b6b3a], .white), ("Champagne", [0xfff1d6, 0xd8b98a], RGBA(0x3a2a08)),
                                                    ("Cosmic", [0x7f5cff, 0x00d4ff], .white), ("Frost Glitter", [0xe6f7ff, 0x9ad7ff], RGBA(0x10324a))]
        for (i, g) in glitters.enumerated() {
            all.append(t(g.0, .sparkle) {
                $0.shape = [ArrowShape.sleek, .round, .chunky, .pin, .dart][i % 5]
                $0.fill = g.1.map { RGBA($0) }
                $0.finish = .glitter
                $0.outline = g.2
                $0.outlineWidth = 1.1
                $0.accent = RGBA(g.1[0])
                if i.isMultiple(of: 3) { $0.motion = .breathe }
            })
        }

        // Outline only.
        let outlines: [(String, UInt32)] = [("Line White", 0xffffff), ("Line Black", 0x161618), ("Line Blue", 0x1e90ff), ("Line Pink", 0xff3aa6),
                                            ("Line Lime", 0x9be22d), ("Line Orange", 0xff8a00), ("Line Violet", 0x8e44ff), ("Line Red", 0xff2d2d)]
        for (i, o) in outlines.enumerated() {
            all.append(t(o.0, .outline) {
                $0.shape = [ArrowShape.sleek, .classic, .round, .triangle][i % 4]
                $0.fill = [RGBA(o.1)]
                $0.finish = .hollow
                $0.outline = o.1 == 0xffffff ? RGBA(0x1d1d1f, 0.9) : .white
                $0.outlineWidth = 1.0
                $0.accent = RGBA(o.1 == 0xffffff ? 0x0a84ff : o.1)
            })
        }

        // More gradients on fresh bodies.
        for (i, g) in gradients.suffix(6).enumerated() {
            all.append(t(g.0, .gradient) {
                $0.shape = [ArrowShape.pin, .chunky, .needle, .round, .triangle, .sleek][i]
                $0.fill = g.1.map { RGBA($0) }
                $0.angle = 100
                $0.accent = RGBA(g.1[0])
                if $0.fill.allSatisfy({ $0.luminance > 0.7 }) { $0.outline = RGBA(0x2a2a2a); $0.outlineWidth = 1.0 }
            })
        }
        return all
    }
}
