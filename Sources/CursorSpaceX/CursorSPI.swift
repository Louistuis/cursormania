import AppKit

/// Bindings to the private WindowServer (SkyLight) cursor calls.
///
/// These are the same calls the system uses to register its own cursors at login.
/// They are looked up at runtime with dlsym, so a missing symbol on a future macOS
/// turns into `isAvailable == false` instead of a crash at launch.
///
/// Signatures were checked against SkyLight on macOS 26.2 by disassembly:
/// `SLSRegisterCursorWithImages(cid, name, global, instant, size, hotspot,
/// frameCount, frameDuration, images, seed)`, with at most 24 frames.
final class CGSCursorAPI {
    static let shared = CGSCursorAPI()

    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias RegisterFn = @convention(c) (Int32, UnsafePointer<CChar>, Bool, Bool, CGSize, CGPoint, Int, CGFloat, CFArray, UnsafeMutablePointer<Int32>) -> Int32
    private typealias CopyFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>, UnsafeMutablePointer<Int>, UnsafeMutablePointer<CGFloat>, UnsafeMutablePointer<Unmanaged<CFArray>?>) -> Int32
    private typealias SetRegisteredFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> Int32
    private typealias ConnIntFn = @convention(c) (Int32, Int32) -> Int32
    private typealias ConnFn = @convention(c) (Int32) -> Int32
    private typealias DockOverrideFn = @convention(c) (Int32, Bool) -> Void
    private typealias GetScaleFn = @convention(c) (Int32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetScaleFn = @convention(c) (Int32, Float) -> Int32

    private let mainConn: MainConnFn?
    private let registerFn: RegisterFn?
    private let copyFn: CopyFn?
    private let setRegisteredFn: SetRegisteredFn?
    private let systemDefinedFn: ConnIntFn?
    private let coreSetFn: ConnIntFn?
    private let unregisterAllFn: ConnFn?
    private let dockOverrideFn: DockOverrideFn?
    private let getScaleFn: GetScaleFn?
    private let setScaleFn: SetScaleFn?

    var isAvailable: Bool { mainConn != nil && registerFn != nil && copyFn != nil && setRegisteredFn != nil }

    private init() {
        let hiServices = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_NOW)
        let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
        let any = dlopen(nil, RTLD_NOW)
        func load<T>(_ names: [String], _: T.Type) -> T? {
            for name in names {
                for handle in [hiServices, skyLight, any] where handle != nil {
                    if let p = dlsym(handle, name) { return unsafeBitCast(p, to: T.self) }
                }
            }
            return nil
        }
        mainConn = load(["CGSMainConnectionID", "SLSMainConnectionID"], MainConnFn.self)
        registerFn = load(["CGSRegisterCursorWithImages", "SLSRegisterCursorWithImages"], RegisterFn.self)
        copyFn = load(["CGSCopyRegisteredCursorImages", "SLSCopyRegisteredCursorImages"], CopyFn.self)
        setRegisteredFn = load(["CGSSetRegisteredCursor", "SLSSetRegisteredCursor"], SetRegisteredFn.self)
        systemDefinedFn = load(["CGSSetSystemDefinedCursor", "SLSSetSystemDefinedCursor"], ConnIntFn.self)
        coreSetFn = load(["CoreCursorSet"], ConnIntFn.self)
        unregisterAllFn = load(["CoreCursorUnregisterAll"], ConnFn.self)
        dockOverrideFn = load(["CGSSetDockCursorOverride", "SLSSetDockCursorOverride"], DockOverrideFn.self)
        getScaleFn = load(["CGSGetCursorScale", "SLSGetCursorScale"], GetScaleFn.self)
        setScaleFn = load(["CGSSetCursorScale", "SLSSetCursorScale"], SetScaleFn.self)
    }

    private var cid: Int32 { mainConn?() ?? 0 }

    @discardableResult
    func register(_ name: String, _ set: CursorImageSet) -> Bool {
        guard let registerFn, let setRegisteredFn, !set.images.isEmpty else { return false }
        var seed: Int32 = 0
        let ok = name.withCString { n in
            registerFn(cid, n, true, true, set.size, set.hotspot, set.frameCount, set.frameDuration, set.images as CFArray, &seed) == 0
        }
        if ok { name.withCString { n in _ = setRegisteredFn(cid, n, &seed) } }
        return ok
    }

    func copy(_ name: String) -> CursorImageSet? {
        guard let copyFn else { return nil }
        var size = CGSize.zero, hot = CGPoint.zero, frames = 0, duration: CGFloat = 0
        var arr: Unmanaged<CFArray>?
        let err = name.withCString { copyFn(cid, $0, &size, &hot, &frames, &duration, &arr) }
        guard err == 0, let images = arr?.takeRetainedValue() as? [CGImage], !images.isEmpty else { return nil }
        return CursorImageSet(size: size, hotspot: hot, frameCount: max(frames, 1), frameDuration: duration, images: images)
    }

    func unregisterAll() { _ = unregisterAllFn?(cid) }
    func coreSet(_ id: Int32) { _ = coreSetFn?(cid, id) }
    func dockOverride(_ on: Bool) { dockOverrideFn?(cid, on) }

    /// Makes WindowServer pick up new images right away: a tiny cursor-scale nudge
    /// forces a redraw, then the arrow is re-selected.
    func refresh() {
        var scale: Float = 1
        if let getScaleFn, getScaleFn(cid, &scale) == 0, let setScaleFn {
            _ = setScaleFn(cid, scale + 0.1)
            _ = setScaleFn(cid, scale)
        }
        _ = systemDefinedFn?(cid, 0)
    }
}

/// One cursor as WindowServer stores it. Each image is one resolution (1x, 2x, 5x,
/// 10x); animated cursors stack their frames top to bottom inside every image.
struct CursorImageSet {
    var size: CGSize
    var hotspot: CGPoint
    var frameCount: Int
    var frameDuration: Double
    var images: [CGImage]
}
