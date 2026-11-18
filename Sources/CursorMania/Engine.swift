import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Puts a theme on the real, system-wide cursor and takes it off again.
///
/// Registrations live in WindowServer, so they stay after CursorMania quits and
/// last until logout. The app re-applies the saved theme at login.
final class CursorEngine {
    static let shared = CursorEngine()

    let api = CGSCursorAPI.shared
    let queue = DispatchQueue(label: "cursormania.engine", qos: .userInitiated)

    private let appliedKey = "engine.themeIsApplied"

    var supportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CursorSpaceX", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    var originalsURL: URL { supportDir.appendingPathComponent("system-cursors.plist") }

    // MARK: Apply

    /// Draws every cursor state for `style` and registers all of them.
    @discardableResult
    func apply(_ style: CursorStyle, userScale: Double) -> Bool {
        guard api.isAvailable else { return false }
        saveOriginalsIfNeeded()
        var ok = true
        for role in CursorRole.all {
            let set = CursorPainter.imageSet(role.glyph, style: style, userScale: userScale)
            for name in role.names where !api.register(name, set) { ok = false }
        }
        api.dockOverride(true)
        api.refresh()
        nudgePointer()
        UserDefaults.standard.set(true, forKey: appliedKey)
        return ok
    }

    func applyAsync(_ style: CursorStyle, userScale: Double, done: ((Bool) -> Void)? = nil) {
        queue.async {
            let ok = self.apply(style, userScale: userScale)
            if let done { DispatchQueue.main.async { done(ok) } }
        }
    }

    // MARK: Restore

    /// Puts the stock macOS cursors back.
    func restoreSystem() {
        guard api.isAvailable else { return }
        api.unregisterAll()
        for i in 0...45 { api.coreSet(Int32(i)) }
        // The arrow and I-beam belong to the system's own registration, which ours
        // replaced, so they are put back from the copy saved before the first theme.
        if let saved = loadOriginals() {
            for (name, set) in saved where name.hasPrefix("com.apple.coregraphics.") { api.register(name, set) }
        }
        api.dockOverride(false)
        api.refresh()
        nudgePointer()
        UserDefaults.standard.set(false, forKey: appliedKey)
    }

    /// The screen only redraws the pointer when the app under it sets its cursor
    /// again. A mouse-moved event at the pointer's own position makes that happen
    /// at once, without moving anything. macOS only allows it once the user has
    /// granted Accessibility; without it the new look shows on the next real move.
    func nudgePointer() {
        guard CGPreflightPostEventAccess(), let loc = CGEvent(source: nil)?.location else { return }
        CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved,
                mouseCursorPosition: loc, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func restoreAsync(done: (() -> Void)? = nil) {
        queue.async {
            self.restoreSystem()
            if let done { DispatchQueue.main.async(execute: done) }
        }
    }

    // MARK: Originals

    /// Copies the system's cursors to disk once, while no theme is on, so
    /// "restore" can always bring back the real ones.
    func saveOriginalsIfNeeded() {
        let fm = FileManager.default
        if fm.fileExists(atPath: originalsURL.path) { return }
        if UserDefaults.standard.bool(forKey: appliedKey) { return }
        var out: [String: Any] = [:]
        for name in CursorRole.everyName {
            guard let set = api.copy(name) else { continue }
            out[name] = [
                "w": set.size.width, "h": set.size.height, "hx": set.hotspot.x, "hy": set.hotspot.y,
                "frames": set.frameCount, "duration": set.frameDuration,
                "reps": set.images.compactMap(Self.png),
            ] as [String: Any]
        }
        guard out["com.apple.coregraphics.Arrow"] != nil,
              let data = try? PropertyListSerialization.data(fromPropertyList: out, format: .binary, options: 0) else { return }
        try? data.write(to: originalsURL, options: .atomic)
    }

    func loadOriginals() -> [String: CursorImageSet]? {
        guard let data = try? Data(contentsOf: originalsURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]] else { return nil }
        var out: [String: CursorImageSet] = [:]
        for (name, d) in dict {
            let reps = (d["reps"] as? [Data] ?? []).compactMap(Self.cgImage)
            guard !reps.isEmpty else { continue }
            out[name] = CursorImageSet(
                size: CGSize(width: d["w"] as? Double ?? 0, height: d["h"] as? Double ?? 0),
                hotspot: CGPoint(x: d["hx"] as? Double ?? 0, y: d["hy"] as? Double ?? 0),
                frameCount: d["frames"] as? Int ?? 1, frameDuration: d["duration"] as? Double ?? 0, images: reps)
        }
        return out
    }

    static func png(_ img: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dst, img, nil)
        return CGImageDestinationFinalize(dst) ? data as Data : nil
    }

    static func cgImage(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    // MARK: Checks

    /// Reads back what WindowServer holds for the arrow, for `--verify`.
    func describe(_ name: String) -> String {
        guard let set = api.copy(name) else { return "\(name): not registered" }
        return "\(name): \(Int(set.size.width))x\(Int(set.size.height)) pt, hotspot \(set.hotspot.x),\(set.hotspot.y), \(set.frameCount) frame(s), reps \(set.images.map { "\($0.width)x\($0.height)" }.joined(separator: " "))"
    }
}
