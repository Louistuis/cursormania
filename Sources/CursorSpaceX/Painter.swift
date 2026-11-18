import AppKit
import CoreText

/// Draws every cursor state for a style. All geometry is in "base points" with a
/// y-down origin at the top-left of the cursor canvas; the painter scales to the
/// requested size and pixel density.
enum CursorPainter {
    static let animatedFrames = 24

    // MARK: Layout

    struct Layout { var canvas: CGSize; var hotspot: CGPoint }

    static func layout(_ g: Glyph, _ s: CursorStyle) -> Layout {
        switch g {
        case .arrow, .contextMenu, .help, .busy, .copy, .alias, .forbidden:
            return s.shape.isDot ? Layout(canvas: CGSize(width: 36, height: 36), hotspot: CGPoint(x: 14, y: 14))
                                 : Layout(canvas: CGSize(width: 34, height: 42), hotspot: CGPoint(x: 9, y: 8))
        case .wait:
            return Layout(canvas: CGSize(width: 30, height: 30), hotspot: CGPoint(x: 15, y: 15))
        case .ibeam:
            return Layout(canvas: CGSize(width: 24, height: 30), hotspot: CGPoint(x: 12, y: 15))
        case .ibeamHorizontal:
            return Layout(canvas: CGSize(width: 30, height: 24), hotspot: CGPoint(x: 15, y: 12))
        case .pointing, .countUp, .countDown, .countUpDown:
            return s.shape.isDot ? Layout(canvas: CGSize(width: 36, height: 36), hotspot: CGPoint(x: 18, y: 18))
                                 : Layout(canvas: CGSize(width: 34, height: 34), hotspot: CGPoint(x: 13.3, y: 5))
        case .openHand, .closedHand:
            return s.shape.isDot ? Layout(canvas: CGSize(width: 36, height: 36), hotspot: CGPoint(x: 18, y: 18))
                                 : Layout(canvas: CGSize(width: 34, height: 34), hotspot: CGPoint(x: 17, y: 17))
        case .zoomIn, .zoomOut:
            return Layout(canvas: CGSize(width: 32, height: 32), hotspot: CGPoint(x: 13, y: 13))
        default:
            return Layout(canvas: CGSize(width: 30, height: 30), hotspot: CGPoint(x: 15, y: 15))
        }
    }

    static func isAnimated(_ g: Glyph, _ s: CursorStyle) -> Bool {
        switch g {
        case .wait, .busy: return true
        case .arrow, .contextMenu, .help, .copy, .alias, .forbidden, .ibeam, .pointing, .openHand, .closedHand:
            return s.motion != .none
        default: return false
        }
    }

    static func frameDuration(_ g: Glyph, _ s: CursorStyle) -> Double {
        switch g {
        case .wait, .busy: return s.motion == .none ? 1.0 / 30 : 1.0 / 20
        default: return s.motion == .pulse || s.motion == .breathe ? 1.0 / 16 : 1.0 / 10
        }
    }

    // MARK: Output

    /// The full set WindowServer wants: 1x, 2x, 5x and 10x images, frames stacked.
    static func imageSet(_ g: Glyph, style s: CursorStyle, userScale: Double) -> CursorImageSet {
        let k = s.scale * userScale
        let lay = layout(g, s)
        let frames = isAnimated(g, s) ? animatedFrames : 1
        let scales: [CGFloat] = frames > 1 ? [1, 2, 5] : [1, 2, 5, 10]
        let images = scales.compactMap { strip(g, s, k: k, px: $0, frames: frames) }
        return CursorImageSet(size: CGSize(width: lay.canvas.width * k, height: lay.canvas.height * k),
                              hotspot: CGPoint(x: lay.hotspot.x * k, y: lay.hotspot.y * k),
                              frameCount: frames, frameDuration: frames > 1 ? frameDuration(g, s) : 0, images: images)
    }

    /// One frame, for previews.
    static func image(_ g: Glyph, style s: CursorStyle, k: Double = 1, px: CGFloat = 2, frame: Int = 0) -> CGImage? {
        let frames = isAnimated(g, s) ? animatedFrames : 1
        let lay = layout(g, s)
        let w = Int((lay.canvas.width * k * px).rounded(.up)), h = Int((lay.canvas.height * k * px).rounded(.up))
        guard let ctx = makeContext(w, h) else { return nil }
        draw(g, s, in: ctx, k: k, px: px, frame: frame % frames, frames: frames, sliceHeight: CGFloat(h))
        return ctx.makeImage()
    }

    private static func strip(_ g: Glyph, _ s: CursorStyle, k: Double, px: CGFloat, frames: Int) -> CGImage? {
        let lay = layout(g, s)
        let w = Int((lay.canvas.width * k * px).rounded()), h = Int((lay.canvas.height * k * px).rounded())
        guard w > 0, h > 0, let ctx = makeContext(w, h * frames) else { return nil }
        for f in 0..<frames {
            ctx.saveGState()
            let y = CGFloat((frames - 1 - f) * h)
            ctx.clip(to: CGRect(x: 0, y: y, width: CGFloat(w), height: CGFloat(h)))
            ctx.translateBy(x: 0, y: y)
            draw(g, s, in: ctx, k: k, px: px, frame: f, frames: frames, sliceHeight: CGFloat(h))
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }

    static func makeContext(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// Draws one frame with the origin at the bottom-left of the frame slice.
    private static func draw(_ g: Glyph, _ s: CursorStyle, in ctx: CGContext, k: Double, px: CGFloat, frame: Int, frames: Int, sliceHeight: CGFloat) {
        if s.shape == .pixel {
            // Pixel themes: draw at one pixel per point with no smoothing, then blow
            // it up with nearest-neighbour so every state reads as pixel art.
            let lay = layout(g, s)
            let lw = Int(lay.canvas.width.rounded(.up)), lh = Int(lay.canvas.height.rounded(.up))
            guard let small = makeContext(lw, lh) else { return }
            small.setShouldAntialias(false)
            small.translateBy(x: 0, y: CGFloat(lh)); small.scaleBy(x: 1, y: -1)
            var flat = s; flat.shadow = 0; flat.glow = nil; flat.gloss = false
            flat.outlineWidth = max(1, flat.outlineWidth.rounded())
            Scene(ctx: small, style: flat, u: 1, frame: frame, frames: frames).draw(g)
            guard let img = small.makeImage() else { return }
            ctx.saveGState()
            ctx.interpolationQuality = .none
            if s.shadow > 0 {
                ctx.setShadow(offset: CGSize(width: 0, height: -1.2 * k * px), blur: 2 * k * px, color: CGColor(gray: 0, alpha: s.shadow))
            }
            ctx.draw(img, in: CGRect(x: 0, y: sliceHeight - CGFloat(lh) * k * px, width: CGFloat(lw) * k * px, height: CGFloat(lh) * k * px))
            ctx.restoreGState()
            return
        }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: sliceHeight)
        ctx.scaleBy(x: k * px, y: -k * px)
        Scene(ctx: ctx, style: s, u: k * px, frame: frame, frames: frames).draw(g)
        ctx.restoreGState()
    }
}

// MARK: - Scene

/// One frame of one cursor being drawn.
private struct Scene {
    let ctx: CGContext
    let style: CursorStyle
    /// Device pixels per base point, for shadow and blur sizes.
    let u: CGFloat
    let frame: Int
    let frames: Int

    var t: Double { frames > 1 ? Double(frame) / Double(frames) : 0 }

    // Per-frame look (motion applied).
    var fills: [RGBA] {
        switch style.motion {
        case .hue: return style.fill.map { $0.hueShifted(t) }
        case .breathe: return style.fill.map { $0.brightness(0.82 + 0.18 * (0.5 + 0.5 * cos(2 * .pi * t))) }
        default: return style.fill
        }
    }
    var glow: RGBA? {
        guard var g = style.glow else { return nil }
        if style.motion == .hue { g = g.hueShifted(t) }
        if style.motion == .pulse { g = g.alpha(g.a * (0.45 + 0.55 * (0.5 + 0.5 * sin(2 * .pi * t)))) }
        return g
    }
    var glowRadius: Double {
        style.motion == .pulse ? style.glowRadius * (0.55 + 0.75 * (0.5 + 0.5 * sin(2 * .pi * t))) : style.glowRadius
    }

    func draw(_ g: Glyph) {
        let shape = style.shape
        switch g {
        case .arrow: pointer()
        case .contextMenu: pointer(); badge(.menu)
        case .help: pointer(); badge(.question)
        case .copy: pointer(); badge(.plus)
        case .alias: pointer(); badge(.curl)
        case .forbidden: pointer(); badge(.forbidden)
        case .busy: pointer(); spinner(center: badgeCenter, radius: 4.8, width: 2.4, spin: true)
        case .wait: spinner(center: CGPoint(x: 15, y: 15), radius: 9.5, width: 3.8, spin: true)
        case .ibeam:
            paint(shape.isDot ? Paths.capsule(x: 12, y: 15, w: 2.6, h: 19) : Paths.ibeam(center: CGPoint(x: 12, y: 15)))
        case .ibeamHorizontal:
            let p = shape.isDot ? Paths.capsule(x: 15, y: 12, w: 19, h: 2.6) : Paths.ibeam(center: CGPoint(x: 15, y: 12), rotated: true)
            paint(p)
        case .pointing:
            if shape.isDot { paint(Paths.dotLink(c: CGPoint(x: 18, y: 18))) } else { paint(Paths.pointingHand(), details: Paths.pointingDetails()) }
        case .countUp, .countDown, .countUpDown:
            if shape.isDot { paint(Paths.dotLink(c: CGPoint(x: 18, y: 18))) } else { paint(Paths.pointingHand(), details: Paths.pointingDetails()) }
            let sym: Badge = g == .countUp ? .up : (g == .countDown ? .down : .upDown)
            badge(sym, at: CGPoint(x: 26, y: 25))
        case .openHand:
            if shape.isDot { paint(Paths.ring(c: CGPoint(x: 18, y: 18), r: 9, w: 2.6)) } else { paint(Paths.openHand(), details: Paths.openDetails()) }
        case .closedHand:
            if shape.isDot { paint(Paths.circle(CGPoint(x: 18, y: 18), 5.2)) } else { paint(Paths.closedHand(), details: Paths.closedDetails()) }
        case .move: paint(Paths.fourWay(c: CGPoint(x: 15, y: 15), diagonal: false))
        case .resizeSquare: paint(Paths.fourWay(c: CGPoint(x: 15, y: 15), diagonal: true))
        case .resize(let dir, let both): paint(Paths.resize(c: CGPoint(x: 15, y: 15), angle: dir.angle, both: both))
        case .crosshair: paint(Paths.crosshair(c: CGPoint(x: 15, y: 15), thin: false))
        case .crosshairThin: paint(Paths.crosshair(c: CGPoint(x: 15, y: 15), thin: true))
        case .cell: paint(Paths.cell(c: CGPoint(x: 15, y: 15)))
        case .poof: paint(Paths.poof(c: CGPoint(x: 15, y: 15)))
        case .camera: paint(Paths.camera(c: CGPoint(x: 15, y: 15)), details: Paths.cameraDetails(c: CGPoint(x: 15, y: 15)))
        case .cameraAlt:
            paint(Paths.camera(c: CGPoint(x: 15, y: 16)), details: Paths.cameraDetails(c: CGPoint(x: 15, y: 16)))
            paint(Paths.brackets(c: CGPoint(x: 15, y: 15)))
        case .zoomIn, .zoomOut:
            paint(Paths.magnifier(c: CGPoint(x: 13, y: 13)))
            symbolLines(Paths.plusMinus(c: CGPoint(x: 13, y: 13), plus: g == .zoomIn, size: 6))
        }
    }

    // MARK: pointer

    var tip: CGPoint { CGPoint(x: 9, y: 8) }
    var dotCenter: CGPoint { CGPoint(x: 14, y: 14) }
    var badgeCenter: CGPoint { style.shape.isDot ? CGPoint(x: 25, y: 25) : CGPoint(x: 21, y: 26.5) }

    func pointer() {
        switch style.shape {
        case .classic, .pixel: paint(Paths.classicArrow(tip: tip))
        case .sleek: paint(Paths.sleekArrow(tip: tip))
        case .dart: paint(Paths.dart(tip: tip))
        case .dot: paint(Paths.circle(dotCenter, 6.2))
        case .ring:
            let p = CGMutablePath()
            p.addPath(Paths.ring(c: dotCenter, r: 7.4, w: 2.5))
            p.addPath(Paths.circle(dotCenter, 1.6))
            paint(p)
        }
    }

    // MARK: styled paint

    func paint(_ path: CGPath, details: CGPath? = nil) {
        let bounds = path.boundingBoxOfPath.insetBy(dx: -0.5, dy: -0.5)
        ctx.saveGState()
        if let glow {
            ctx.setShadow(offset: .zero, blur: glowRadius * u, color: glow.cg)
        } else if style.shadow > 0 {
            ctx.setShadow(offset: CGSize(width: 0, height: -1.3 * u), blur: 2.6 * u, color: CGColor(gray: 0, alpha: style.shadow))
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)

        // Outline: stroke the whole silhouette, then punch the inside out so
        // overlapping parts (fingers, palm) leave no inner seams.
        if style.outlineWidth > 0 {
            ctx.addPath(path)
            ctx.setLineJoin(.round); ctx.setLineCap(.round)
            ctx.setLineWidth(style.outlineWidth * 2)
            ctx.setStrokeColor(style.outline.cg)
            ctx.strokePath()
            ctx.addPath(path)
            ctx.setBlendMode(.clear)
            ctx.fillPath(using: .winding)
            ctx.setBlendMode(.normal)
        }

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip(using: .winding)
        fill(bounds)
        if style.gloss || style.motion == .shimmer { gloss(bounds) }
        if let details {
            ctx.addPath(details)
            ctx.setLineWidth(0.85)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(style.outline.alpha(style.outline.a * 0.55).cg)
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    func fill(_ r: CGRect) {
        let colors = fills
        if colors.count == 1 {
            ctx.setFillColor(colors[0].cg)
            ctx.fill(r)
            return
        }
        guard let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cg) as CFArray, locations: nil) else { return }
        let a = style.angle * .pi / 180
        let d = CGPoint(x: cos(a), y: sin(a))
        let half = (abs(r.width * d.x) + abs(r.height * d.y)) / 2
        let c = CGPoint(x: r.midX, y: r.midY)
        ctx.drawLinearGradient(grad, start: CGPoint(x: c.x - d.x * half, y: c.y - d.y * half),
                               end: CGPoint(x: c.x + d.x * half, y: c.y + d.y * half),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func gloss(_ r: CGRect) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)
        if style.gloss {
            // Soft top highlight, like light hitting glass.
            let colors = [CGColor(gray: 1, alpha: 0.62), CGColor(gray: 1, alpha: 0.08), CGColor(gray: 1, alpha: 0)] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 0.6]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY), options: [])
            }
        }
        if style.motion == .shimmer {
            let pos = -0.4 + 1.8 * t
            let colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.75), CGColor(gray: 1, alpha: 0)] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                let x = r.minX + (r.width + r.height) * pos
                ctx.drawLinearGradient(g, start: CGPoint(x: x - 5, y: r.minY), end: CGPoint(x: x + 5, y: r.minY + 6), options: [])
            }
        }
    }

    /// White strokes drawn over a filled glyph (zoom plus/minus).
    func symbolLines(_ p: CGPath) {
        ctx.saveGState()
        ctx.addPath(p)
        ctx.setLineWidth(1.9); ctx.setLineCap(.round)
        let dark = (fills.first?.luminance ?? 0) < 0.6
        ctx.setStrokeColor((dark ? RGBA.white : RGBA.black).alpha(0.95).cg)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: badges

    enum Badge { case plus, curl, forbidden, question, menu, up, down, upDown }

    func badge(_ kind: Badge, at center: CGPoint? = nil) {
        let c = center ?? badgeCenter
        let r: CGFloat = 5.4
        let color: RGBA
        switch kind {
        case .plus: color = RGBA(0x30c45a)
        case .forbidden: color = RGBA(0xff3b30)
        default: color = style.accent.luminance > 0.62 ? style.accent.mix(.black, 0.38) : style.accent
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.8 * u), blur: 1.8 * u, color: CGColor(gray: 0, alpha: 0.35))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - r - 1.1, y: c.y - r - 1.1, width: (r + 1.1) * 2, height: (r + 1.1) * 2))
        ctx.setFillColor(color.cg)
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.setLineWidth(1.5); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        switch kind {
        case .plus:
            ctx.move(to: CGPoint(x: c.x - 2.6, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + 2.6, y: c.y))
            ctx.move(to: CGPoint(x: c.x, y: c.y - 2.6)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + 2.6))
            ctx.strokePath()
        case .forbidden:
            ctx.setLineWidth(1.3)
            ctx.strokeEllipse(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
            ctx.move(to: CGPoint(x: c.x - 2.1, y: c.y + 2.1)); ctx.addLine(to: CGPoint(x: c.x + 2.1, y: c.y - 2.1))
            ctx.strokePath()
        case .curl:
            ctx.addArc(center: CGPoint(x: c.x + 0.6, y: c.y + 0.8), radius: 2.3, startAngle: .pi, endAngle: .pi * 1.75, clockwise: false)
            ctx.strokePath()
            let tipP = CGPoint(x: c.x + 2.9, y: c.y - 1.4)
            ctx.move(to: CGPoint(x: tipP.x - 2.2, y: tipP.y - 0.6)); ctx.addLine(to: tipP); ctx.addLine(to: CGPoint(x: tipP.x - 0.4, y: tipP.y + 2.1))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: c.x - 1.7, y: c.y + 0.8)); ctx.addLine(to: CGPoint(x: c.x - 1.7, y: c.y + 2.8)); ctx.strokePath()
        case .question:
            text("?", at: c, size: 8.4)
        case .menu:
            ctx.setLineWidth(1.2)
            for dy in [-2.0, 0.0, 2.0] { ctx.move(to: CGPoint(x: c.x - 2.5, y: c.y + dy)); ctx.addLine(to: CGPoint(x: c.x + 2.5, y: c.y + dy)) }
            ctx.strokePath()
        case .up, .down, .upDown:
            func chevron(_ dir: CGFloat, _ oy: CGFloat) {
                ctx.move(to: CGPoint(x: c.x - 2.2, y: c.y + oy + 1.1 * dir))
                ctx.addLine(to: CGPoint(x: c.x, y: c.y + oy - 1.1 * dir))
                ctx.addLine(to: CGPoint(x: c.x + 2.2, y: c.y + oy + 1.1 * dir))
            }
            if kind == .up { chevron(1, 0) } else if kind == .down { chevron(-1, 0) } else { chevron(1, -1.6); chevron(-1, 1.6) }
            ctx.strokePath()
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    func text(_ s: String, at c: CGPoint, size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.white])
        let line = CTLineCreateWithAttributedString(attr)
        let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: c.x - b.width / 2 - b.minX, y: c.y + b.height / 2 + b.minY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: spinner

    func spinner(center c: CGPoint, radius r: CGFloat, width w: CGFloat, spin: Bool) {
        let colors = fills.count > 1 ? fills : [fills[0], fills[0]]
        let accentDot = fills.count == 1 && fills[0].luminance < 0.15 || fills[0].luminance > 0.9
        let ring = accentDot ? [style.accent, style.accent.hueShifted(0.08)] : colors
        ctx.saveGState()
        if let glow {
            ctx.setShadow(offset: .zero, blur: glowRadius * u, color: glow.cg)
        } else if style.shadow > 0 {
            ctx.setShadow(offset: CGSize(width: 0, height: -1 * u), blur: 2 * u, color: CGColor(gray: 0, alpha: style.shadow))
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        // Outline ring and faint track.
        ctx.setLineWidth(w + style.outlineWidth * 2)
        ctx.setStrokeColor(style.outline.cg)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setLineWidth(w)
        ctx.setBlendMode(.clear)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(ring[0].alpha(0.22).cg)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        // Comet arc that fades from its head.
        let start = spin ? 2 * .pi * t : 0
        let segments = 40
        let sweep = 1.6 * Double.pi
        ctx.setLineCap(.butt)
        for i in 0..<segments {
            let f = Double(i) / Double(segments)
            let a0 = start + sweep * f
            let a1 = start + sweep * (f + 1.0 / Double(segments)) + 0.02
            let col = interpolate(ring, f).alpha(pow(f, 1.4))
            ctx.setStrokeColor(col.cg)
            ctx.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
            ctx.strokePath()
        }
        // Rounded head.
        let head = start + sweep
        ctx.setFillColor(interpolate(ring, 1).cg)
        let hc = CGPoint(x: c.x + r * cos(head), y: c.y + r * sin(head))
        ctx.fillEllipse(in: CGRect(x: hc.x - w / 2, y: hc.y - w / 2, width: w, height: w))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    func interpolate(_ cs: [RGBA], _ f: Double) -> RGBA {
        guard cs.count > 1 else { return cs[0] }
        let x = min(max(f, 0), 1) * Double(cs.count - 1)
        let i = min(Int(x), cs.count - 2)
        return cs[i].mix(cs[i + 1], x - Double(i))
    }
}

// MARK: - Paths

private enum Paths {
    static func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: nil)
    }

    static func rotRect(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ deg: CGFloat) -> CGPath {
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: deg * .pi / 180)
        return CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: &t)
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
    }

    static func ring(c: CGPoint, r: CGFloat, w: CGFloat) -> CGPath {
        circle(c, r).copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4)
    }

    static func polygon(_ pts: [CGPoint], radius: CGFloat, offset o: CGPoint = .zero, transform: CGAffineTransform = .identity) -> CGPath {
        let p = pts.map { CGPoint(x: $0.x + o.x, y: $0.y + o.y).applying(transform) }
        let path = CGMutablePath()
        let n = p.count
        let start = CGPoint(x: (p[n - 1].x + p[0].x) / 2, y: (p[n - 1].y + p[0].y) / 2)
        path.move(to: start)
        for i in 0..<n {
            path.addArc(tangent1End: p[i], tangent2End: p[(i + 1) % n], radius: radius)
        }
        path.closeSubpath()
        return path
    }

    static func union(_ parts: [CGPath]) -> CGPath {
        let m = CGMutablePath()
        for p in parts { m.addPath(p) }
        return m
    }

    // Pointers. The tip sits exactly on the hotspot.
    static func classicArrow(tip: CGPoint) -> CGPath {
        let p = CGMutablePath()
        let pts: [CGPoint] = [.init(x: 0, y: 0), .init(x: 0, y: 16.8), .init(x: 4.0, y: 13.1), .init(x: 6.6, y: 19.3),
                              .init(x: 9.4, y: 18.2), .init(x: 6.9, y: 12.3), .init(x: 12.3, y: 12.3)]
        p.move(to: tip)
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: tip.x + q.x, y: tip.y + q.y)) }
        p.closeSubpath()
        return p
    }

    static func sleekArrow(tip: CGPoint) -> CGPath {
        polygon([.init(x: -0.3, y: -0.6), .init(x: 0.2, y: 16.4), .init(x: 4.8, y: 12.4), .init(x: 11.8, y: 11.8)], radius: 1.3, offset: tip)
    }

    static func dart(tip: CGPoint) -> CGPath {
        polygon([.init(x: -0.5, y: -0.5), .init(x: 15.2, y: 6.4), .init(x: 7.6, y: 7.9), .init(x: 6.0, y: 15.4)], radius: 1.1, offset: tip)
    }

    static func capsule(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        rr(x - w / 2, y - h / 2, w, h, min(w, h) / 2)
    }

    static func ibeam(center c: CGPoint, rotated: Bool = false) -> CGPath {
        let parts = [
            rr(-4.6, -9.6, 9.2, 2.3, 1.15),
            rr(-1.1, -9.2, 2.2, 18.4, 0.6),
            rr(-4.6, 7.3, 9.2, 2.3, 1.15),
            rr(-2.8, -0.8, 5.6, 1.6, 0.8),
        ]
        let m = CGMutablePath()
        var t = CGAffineTransform(translationX: c.x, y: c.y)
        if rotated { t = t.rotated(by: .pi / 2) }
        for p in parts { m.addPath(p, transform: t) }
        return m
    }

    static func dotLink(c: CGPoint) -> CGPath {
        union([ring(c: c, r: 9.5, w: 2.4), circle(c, 3.6)])
    }

    // Hands.
    static func pointingHand() -> CGPath {
        union([
            rr(11.0, 2.8, 4.6, 15.5, 2.3),
            rr(15.3, 10.6, 4.2, 8.6, 2.1),
            rr(19.2, 11.8, 4.0, 8.0, 2.0),
            rr(22.9, 13.4, 3.6, 7.2, 1.8),
            rr(11.0, 14.6, 15.5, 13.6, 5.2),
            rotRect(CGPoint(x: 9.6, y: 20.2), 4.4, 9.6, 2.2, -42),
        ])
    }

    static func pointingDetails() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 15.4, y: 15.3)); p.addLine(to: CGPoint(x: 15.4, y: 18.4))
        p.move(to: CGPoint(x: 19.3, y: 16.4)); p.addLine(to: CGPoint(x: 19.3, y: 19.0))
        p.move(to: CGPoint(x: 22.9, y: 17.6)); p.addLine(to: CGPoint(x: 22.9, y: 19.6))
        return p
    }

    static func openHand() -> CGPath {
        union([
            rotRect(CGPoint(x: 12.0, y: 11.0), 4.0, 12.5, 2.0, -14),
            rotRect(CGPoint(x: 16.2, y: 9.0), 4.1, 13.5, 2.05, -3),
            rotRect(CGPoint(x: 20.3, y: 10.0), 3.9, 12.5, 1.95, 7),
            rotRect(CGPoint(x: 24.0, y: 13.2), 3.5, 10.0, 1.75, 18),
            rr(10.2, 13.6, 15.8, 13.8, 5.6),
            rotRect(CGPoint(x: 8.9, y: 19.6), 4.2, 10.4, 2.1, -50),
        ])
    }

    static func openDetails() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 14.3, y: 15.0)); p.addLine(to: CGPoint(x: 14.1, y: 17.6))
        p.move(to: CGPoint(x: 18.3, y: 14.8)); p.addLine(to: CGPoint(x: 18.3, y: 17.4))
        p.move(to: CGPoint(x: 22.2, y: 15.6)); p.addLine(to: CGPoint(x: 22.0, y: 18.0))
        return p
    }

    static func closedHand() -> CGPath {
        union([
            rr(9.8, 9.6, 4.1, 7.0, 2.05),
            rr(13.7, 8.8, 4.1, 7.6, 2.05),
            rr(17.6, 9.2, 4.0, 7.2, 2.0),
            rr(21.3, 10.4, 3.7, 6.6, 1.85),
            rr(9.6, 12.4, 15.8, 13.8, 5.6),
            rotRect(CGPoint(x: 9.2, y: 18.4), 4.0, 8.4, 2.0, -64),
        ])
    }

    static func closedDetails() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 13.8, y: 13.0)); p.addLine(to: CGPoint(x: 13.8, y: 15.6))
        p.move(to: CGPoint(x: 17.6, y: 13.0)); p.addLine(to: CGPoint(x: 17.6, y: 15.6))
        p.move(to: CGPoint(x: 21.3, y: 13.4)); p.addLine(to: CGPoint(x: 21.3, y: 15.8))
        return p
    }

    // Arrows for move and resize, built along the x axis then rotated.
    static func doubleArrow(length L: CGFloat) -> [CGPoint] {
        let hl: CGFloat = 6.2, hw: CGFloat = 7.6, t: CGFloat = 2.4
        return [.init(x: -L / 2, y: 0), .init(x: -L / 2 + hl, y: -hw / 2), .init(x: -L / 2 + hl, y: -t / 2),
                .init(x: L / 2 - hl, y: -t / 2), .init(x: L / 2 - hl, y: -hw / 2), .init(x: L / 2, y: 0),
                .init(x: L / 2 - hl, y: hw / 2), .init(x: L / 2 - hl, y: t / 2), .init(x: -L / 2 + hl, y: t / 2),
                .init(x: -L / 2 + hl, y: hw / 2)]
    }

    static func resize(c: CGPoint, angle: Double, both: Bool) -> CGPath {
        let rot = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle * .pi / 180)
        if both {
            let diag = Int(angle) % 90 != 0
            return polygon(doubleArrow(length: diag ? 19 : 21), radius: 0.5, transform: rot)
        }
        let L: CGFloat = 17, hl: CGFloat = 6.4, hw: CGFloat = 7.8, t: CGFloat = 2.4
        let arrow: [CGPoint] = [.init(x: L / 2, y: 0), .init(x: L / 2 - hl, y: -hw / 2), .init(x: L / 2 - hl, y: -t / 2),
                                .init(x: -L / 2 + 1.6, y: -t / 2), .init(x: -L / 2 + 1.6, y: t / 2),
                                .init(x: L / 2 - hl, y: t / 2), .init(x: L / 2 - hl, y: hw / 2)]
        let m = CGMutablePath()
        m.addPath(polygon(arrow, radius: 0.5, transform: rot))
        var bt = rot
        m.addPath(CGPath(roundedRect: CGRect(x: -L / 2 - 0.8, y: -6, width: 2.4, height: 12), cornerWidth: 1, cornerHeight: 1, transform: &bt))
        return m
    }

    static func fourWay(c: CGPoint, diagonal: Bool) -> CGPath {
        let a: CGFloat = diagonal ? 45 : 0
        let m = CGMutablePath()
        for extra: CGFloat in [0, 90] {
            let rot = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: (a + extra) * .pi / 180)
            m.addPath(polygon(doubleArrow(length: diagonal ? 22 : 23), radius: 0.5, transform: rot))
        }
        m.addPath(rr(c.x - 2.2, c.y - 2.2, 4.4, 4.4, 1))
        return m
    }

    static func crosshair(c: CGPoint, thin: Bool) -> CGPath {
        let t: CGFloat = thin ? 1.2 : 2.0, gap: CGFloat = thin ? 2.6 : 3.2, len: CGFloat = thin ? 11.5 : 10
        var parts = [
            rr(c.x - t / 2, c.y - len, t, len - gap, t / 2), rr(c.x - t / 2, c.y + gap, t, len - gap, t / 2),
            rr(c.x - len, c.y - t / 2, len - gap, t, t / 2), rr(c.x + gap, c.y - t / 2, len - gap, t, t / 2),
        ]
        if !thin { parts.append(circle(c, 1.3)) }
        return union(parts)
    }

    static func cell(c: CGPoint) -> CGPath {
        union([rr(c.x - 3.2, c.y - 10, 6.4, 20, 1.4), rr(c.x - 10, c.y - 3.2, 20, 6.4, 1.4)])
    }

    static func poof(c: CGPoint) -> CGPath {
        union([circle(CGPoint(x: c.x - 5, y: c.y + 2), 5), circle(CGPoint(x: c.x + 1, y: c.y - 3), 6.2),
               circle(CGPoint(x: c.x + 6, y: c.y + 2.5), 4.6), rr(c.x - 9, c.y + 1, 18, 6.4, 3.2)])
    }

    static func camera(c: CGPoint) -> CGPath {
        union([rr(c.x - 9, c.y - 5, 18, 12.5, 3), rr(c.x - 3.6, c.y - 7.6, 7.2, 3.6, 1.4)])
    }

    static func cameraDetails(c: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: c.x - 3.2, y: c.y - 2.0, width: 6.4, height: 6.4))
        return p
    }

    static func brackets(c: CGPoint) -> CGPath {
        let m = CGMutablePath()
        let s: CGFloat = 13.5, l: CGFloat = 3.6, t: CGFloat = 1.6
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            let x = c.x + CGFloat(sx) * s, y = c.y + CGFloat(sy) * s
            m.addPath(rr(sx < 0 ? x : x - t, sy < 0 ? y : y - l, t, l, t / 2))
            m.addPath(rr(sx < 0 ? x : x - l, sy < 0 ? y : y - t, l, t, t / 2))
        }
        return m
    }

    static func magnifier(c: CGPoint) -> CGPath {
        let m = CGMutablePath()
        m.addPath(circle(c, 8.2))
        m.addPath(rotRect(CGPoint(x: c.x + 9.6, y: c.y + 9.6), 3.6, 9, 1.8, -45))
        return m
    }

    static func plusMinus(c: CGPoint, plus: Bool, size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - s / 2, y: c.y)); p.addLine(to: CGPoint(x: c.x + s / 2, y: c.y))
        if plus { p.move(to: CGPoint(x: c.x, y: c.y - s / 2)); p.addLine(to: CGPoint(x: c.x, y: c.y + s / 2)) }
        return p
    }
}
