import AppKit
import Observation
import SwiftUI

@main
struct TickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Everything lives in the menu bar item and the focus window, both owned by AppDelegate.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let stats = StatsStore()
    private let sound = SoundPlayer()
    private let tasks = TaskStore()
    private lazy var engine = TimerEngine(settings: settings, stats: stats, sound: sound, tasks: tasks)

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var focusWindow: NSWindow?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"),
           CommandLine.arguments.indices.contains(flag + 1) {
            Snapshot.run(into: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
            exit(0)
        }
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--icon"), args.indices.contains(flag + 1) {
            let style = args.indices.contains(flag + 2) ? IconStyle(rawValue: args[flag + 2]) : nil
            AppIconView.render(style ?? AppIconView.chosen, to: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }
        if let flag = args.firstIndex(of: "--icon-compare"), args.indices.contains(flag + 1) {
            let styles = args[(flag + 2)...].compactMap(IconStyle.init(rawValue:))
            AppIconView.renderComparison(styles, to: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }
        if let flag = args.firstIndex(of: "--icon-sheet"), args.indices.contains(flag + 1) {
            AppIconView.renderSheet(to: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }

        NSApp.setActivationPolicy(.accessory)
        settings.applyAppearance()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.imagePosition = .imageOnly

        let panel = PanelView(openFocusWindow: { [weak self] in self?.showFocusWindow() })
        popover.contentViewController = NSHostingController(rootView: inject(panel))
        popover.contentSize = NSSize(width: 320, height: 540)
        popover.behavior = .transient

        trackStatusItem()
        trackAppearance()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(systemThemeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        hotKey = HotKey { [weak self] in self?.engine.toggle() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.pause() // also turns Do Not Disturb back off
    }

    /// A popover attached to the menu bar inherits the menu bar's look (often dark, depending on
    /// the wallpaper), not the app's. So the panel and focus window get the chosen appearance explicitly.
    private func trackAppearance() {
        withObservationTracking {
            applyWindowAppearance(settings.appearance)
        } onChange: {
            DispatchQueue.main.async { [weak self] in self?.trackAppearance() }
        }
    }

    @objc private func systemThemeChanged() {
        // The system setting lands in defaults slightly after the notification.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            applyWindowAppearance(settings.appearance)
        }
    }

    private func applyWindowAppearance(_ appearance: Appearance) {
        let dark = switch appearance {
        case .light: false
        case .dark: true
        case .system: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
        let resolved = NSAppearance(named: dark ? .darkAqua : .aqua)
        popover.appearance = resolved
        focusWindow?.appearance = resolved
    }

    private func inject<V: View>(_ view: V) -> some View {
        view.environment(engine).environment(settings).environment(stats).environment(tasks)
    }

    /// Redraws the menu bar pill whenever the time, phase or running state changes.
    private func trackStatusItem() {
        withObservationTracking {
            statusItem.button?.image = MenuBarPill.image(
                minutes: engine.minutesText, seconds: engine.secondsText,
                phase: engine.phase, running: engine.isRunning, fresh: engine.isFresh)
        } onChange: {
            DispatchQueue.main.async { [weak self] in self?.trackStatusItem() }
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showQuickMenu()
        } else {
            togglePopover()
        }
    }

    /// Right-click menu on the pill: control the timer without opening the panel.
    private func showQuickMenu() {
        popover.performClose(nil)
        let menu = NSMenu()
        let toggleTitle = engine.isRunning ? "Pause" : (engine.isFresh ? "Start" : "Resume")
        menu.addItem(menuItem(toggleTitle, #selector(menuToggle), key: "p", modifiers: [.command, .option]))
        menu.addItem(menuItem("Skip", #selector(menuSkip)))
        menu.addItem(menuItem("Reset", #selector(menuReset)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Open Focus Window", #selector(menuOpenFocus)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Tick Focus", #selector(menuQuit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "",
                          modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    @objc private func menuToggle() { engine.toggle() }
    @objc private func menuSkip() { engine.skip() }
    @objc private func menuReset() { engine.reset() }
    @objc private func menuOpenFocus() { showFocusWindow() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showFocusWindow() {
        popover.performClose(nil)
        if focusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 380),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = "Tick Focus"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.fullScreenPrimary]
            window.contentView = NSHostingView(rootView: inject(FlipClockView()))
            window.center()
            window.setFrameAutosaveName("FocusWindow")
            focusWindow = window
            applyWindowAppearance(settings.appearance)
        }
        NSApp.activate(ignoringOtherApps: true)
        focusWindow?.makeKeyAndOrderFront(nil)
    }
}

