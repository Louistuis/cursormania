import SwiftUI
import AppKit

struct CursorManiaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("cursormania", id: "main") {
            MainView()
                .environmentObject(model)
                .background(WindowOpener())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Cursor") {
                Button("Shuffle") { model.shuffle() }.keyboardShortcut("r")
                Button("Make a Cursor…") { model.startCreate(from: nil) }.keyboardShortcut("n")
                Divider()
                Button("Restore macOS Cursor") { model.restore() }.keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            Image(systemName: "cursorarrow.rays")
        }
    }
}

/// Keeps a way to reopen the window from AppKit code (Dock click, menu bar).
private struct WindowOpener: View {
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Color.clear.onAppear {
            AppDelegate.openMain = { openWindow(id: "main") }
            NSApp.setActivationPolicy(.regular)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) var openWindow

    var quick: [CursorTheme] {
        let favs = model.allThemes.filter { model.favorites.contains($0.id) }
        return favs.isEmpty ? Array(Catalog.themes.prefix(8)) : favs
    }

    var body: some View {
        Text(model.active.map { "wearing \($0.name.lowercased())" } ?? "stock macOS cursor")
        Divider()
        ForEach(quick) { t in
            Button {
                model.apply(t)
            } label: {
                Label {
                    Text(t.name.lowercased())
                } icon: {
                    Image(nsImage: menuIcon(t))
                }
            }
        }
        Divider()
        Button("shuffle") { model.shuffle() }
        Button("make a cursor…") {
            model.startCreate(from: nil)
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("restore macOS cursor") { model.restore() }.disabled(model.active == nil)
        Divider()
        Button("open cursormania…") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    func menuIcon(_ t: CursorTheme) -> NSImage {
        let src = PreviewCache.shared.image(t, .arrow)
        let s = 16 / max(src.size.width, src.size.height)
        let img = NSImage(size: NSSize(width: src.size.width * s, height: src.size.height * s))
        img.lockFocus()
        src.draw(in: NSRect(origin: .zero, size: img.size))
        img.unlockFocus()
        return img
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openMain: (() -> Void)?
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == AEEventID(kAEOpenApplication),
           event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem) {
            launchedAtLogin = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = CursorEngine.shared
        engine.queue.async { engine.saveOriginalsIfNeeded() }
        Task { @MainActor in AppModel.shared.reapplySaved() }

        // macOS can drop registered cursors on wake or a user switch; put them back.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.screensDidWakeNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { Task { @MainActor in AppModel.shared.reapplySaved() } }
            }
        }

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let w = note.object as? NSWindow, w.identifier?.rawValue.contains("main") == true || w.title == "cursormania" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) { NSApp.setActivationPolicy(.accessory) }
            }
        }

        if launchedAtLogin {
            DispatchQueue.main.async {
                for w in NSApp.windows where w.canBecomeMain { w.close() }
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.setActivationPolicy(.regular); AppDelegate.openMain?() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
