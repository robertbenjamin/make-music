import AppKit
import WebKit

enum Mode: Int { case phone = 0, desktop = 1
    var size: NSSize { self == .phone ? NSSize(width: 390, height: 844) : NSSize(width: 1100, height: 820) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    var window: NSWindow!
    var web: WKWebView!
    let seg = NSSegmentedControl(labels: ["Phone", "Desktop"], trackingMode: .selectOne, target: nil, action: nil)
    var mode: Mode = Mode(rawValue: UserDefaults.standard.integer(forKey: "mode")) ?? .desktop
    var savedFrames: [Mode: NSRect] = [:]

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMenu()
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()   // keeps progress, notes and settings between launches
        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self; web.uiDelegate = self
        web.setValue(false, forKey: "drawsBackground")   // no white flash in dark mode

        window = NSWindow(contentRect: NSRect(origin: .zero, size: mode.size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "The CAM System"
        window.titleVisibility = .hidden
        window.contentView = web
        window.delegate = self
        window.backgroundColor = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.078, green: 0.082, blue: 0.094, alpha: 1) : NSColor(srgbRed: 0.957, green: 0.961, blue: 0.969, alpha: 1) }
        let tb = NSToolbar(identifier: "main"); tb.delegate = self; tb.displayMode = .iconOnly
        window.toolbar = tb; window.toolbarStyle = .unifiedCompact
        seg.target = self; seg.action = #selector(segChanged)
        seg.selectedSegment = mode.rawValue
        window.setFrameAutosaveName("CAMWindow-\(mode.rawValue)")
        if !window.setFrameUsingName("CAMWindow-\(mode.rawValue)") { window.center() }
        applyLimits()

        let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "site")!
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(web)
        NSApp.activate()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // MARK: phone / desktop
    @objc func segChanged() { setMode(Mode(rawValue: seg.selectedSegment)!) }
    @objc func phone() { setMode(.phone) }
    @objc func desktop() { setMode(.desktop) }
    func applyLimits() {
        if mode == .phone { window.minSize = NSSize(width: 320, height: 480); window.maxSize = NSSize(width: 480, height: 10000) }
        else { window.minSize = NSSize(width: 700, height: 480); window.maxSize = NSSize(width: 10000, height: 10000) }
    }
    func setMode(_ m: Mode) {
        seg.selectedSegment = m.rawValue
        guard m != mode else { return }
        window.saveFrame(usingName: "CAMWindow-\(mode.rawValue)")
        mode = m; UserDefaults.standard.set(m.rawValue, forKey: "mode")
        applyLimits()
        let old = window.frame
        var f = NSRect(origin: .zero, size: window.frameRect(forContentRect: NSRect(origin: .zero, size: m.size)).size)
        if let saved = NSWindow.FrameAutosaveName("CAMWindow-\(m.rawValue)") as String?,
           let str = UserDefaults.standard.string(forKey: "NSWindow Frame \(saved)") {
            let r = NSRectFromString(str.split(separator: " ").prefix(4).joined(separator: " ")); if r.width > 0 { f.size = r.size }
        }
        f.origin = NSPoint(x: old.midX - f.width / 2, y: old.maxY - f.height)   // keep the top edge, stay centred
        if let vis = window.screen?.visibleFrame { f = f.intersection(vis).width > 0 ? clamp(f, vis) : f }
        window.setFrameAutosaveName("CAMWindow-\(m.rawValue)")
        window.setFrame(f, display: true, animate: true)
    }
    func clamp(_ f: NSRect, _ v: NSRect) -> NSRect {
        var r = f; r.size.height = min(r.height, v.height); r.size.width = min(r.width, v.width)
        r.origin.x = max(v.minX, min(r.origin.x, v.maxX - r.width)); r.origin.y = max(v.minY, min(r.origin.y, v.maxY - r.height)); return r
    }
    func windowDidEndLiveResize(_ n: Notification) { window.saveFrame(usingName: "CAMWindow-\(mode.rawValue)") }

    // MARK: toolbar
    let modeID = NSToolbarItem.Identifier("mode")
    func toolbarAllowedItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, modeID] }
    func toolbarDefaultItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, modeID] }
    func toolbar(_ t: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar f: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        seg.setImage(NSImage(systemSymbolName: "iphone", accessibilityDescription: "Phone"), forSegment: 0)
        seg.setImage(NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Desktop"), forSegment: 1)
        seg.setLabel("", forSegment: 0); seg.setLabel("", forSegment: 1)
        seg.setToolTip("Phone layout (⌘1)", forSegment: 0); seg.setToolTip("Desktop layout (⌘2)", forSegment: 1)
        item.view = seg; item.label = "Layout"; item.toolTip = "Phone or desktop layout"
        return item
    }

    // MARK: links open in the default browser
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = a.request.url, u.scheme == "http" || u.scheme == "https", a.navigationType == .linkActivated {
            NSWorkspace.shared.open(u); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url { NSWorkspace.shared.open(u) }; return nil
    }

    // MARK: menus
    @objc func reload() { web.reload() }
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://cam.robertbenjamin.co")!) }
    @objc func openVideo() { NSWorkspace.shared.open(URL(string: "https://www.youtube.com/watch?v=pOvyNUoNOng")!) }
    func buildMenu() {
        let main = NSMenu()
        func sub(_ title: String, _ items: [NSMenuItem]) { let m = NSMenu(title: title); items.forEach(m.addItem); let i = NSMenuItem(); i.submenu = m; main.addItem(i) }
        func it(_ t: String, _ s: Selector?, _ k: String = "", _ mods: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: t, action: s, keyEquivalent: k); i.keyEquivalentModifierMask = mods; if let target { i.target = target }; return i }
        sub("CAM", [it("About The CAM System", #selector(NSApplication.orderFrontStandardAboutPanel(_:))), .separator(),
                    it("Hide", #selector(NSApplication.hide(_:)), "h"), it("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
                    it("Show All", #selector(NSApplication.unhideAllApplications(_:))), .separator(),
                    it("Quit The CAM System", #selector(NSApplication.terminate(_:)), "q")])
        sub("Edit", [it("Undo", Selector(("undo:")), "z"), it("Redo", Selector(("redo:")), "z", [.command, .shift]), .separator(),
                     it("Cut", #selector(NSText.cut(_:)), "x"), it("Copy", #selector(NSText.copy(_:)), "c"),
                     it("Paste", #selector(NSText.paste(_:)), "v"), it("Select All", #selector(NSText.selectAll(_:)), "a")])
        sub("View", [it("Phone Layout", #selector(phone), "1", target: self), it("Desktop Layout", #selector(desktop), "2", target: self), .separator(),
                     it("Reload", #selector(reload), "r", target: self), .separator(),
                     it("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])])
        sub("Window", [it("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"), it("Zoom", #selector(NSWindow.performZoom(_:))),
                       it("Close", #selector(NSWindow.performClose(_:)), "w")])
        sub("Help", [it("Open cam.robertbenjamin.co", #selector(openSite), target: self), it("Watch Luca Bade's Video", #selector(openVideo), target: self)])
        NSApp.mainMenu = main
        NSApp.windowsMenu = main.items[3].submenu
    }
}

@main struct CAMApp {
    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate(); app.delegate = d
        app.setActivationPolicy(.regular)
        app.run()
    }
}
