import AppKit
import SwiftUI

/// `Tick --snapshot <dir>` renders every screen in both colors and both appearances to PNGs, for checking the visuals.
enum Snapshot {
    @MainActor static var isRendering = false

    @MainActor
    static func run(into dir: URL) {
        isRendering = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = AppSettings()
        let stats = StatsStore(inMemory: true)
        stats.seedSample()
        let engine = TimerEngine(settings: settings, stats: stats, sound: SoundPlayer())
        engine.label = "Python course"

        for theme in ThemeColor.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let name = "\(theme.rawValue)-\(scheme == .dark ? "dark" : "light")"
                let bg = Palette.of(scheme, theme).bg
                let env = Env(scheme: scheme, theme: theme, engine: engine, settings: settings, stats: stats)
                save(PanelView(tab: .timer), env, dir.appendingPathComponent("timer-\(name).png"))
                // Stats and Settings scroll in the app; render them full length here.
                save(StatsTab().padding(14).frame(width: 320).background(bg), env,
                     dir.appendingPathComponent("stats-\(name).png"))
                save(SettingsTab(soundListOpen: false).padding(14).frame(width: 320).background(bg), env,
                     dir.appendingPathComponent("settings-\(name).png"))
                save(FlipClockView().frame(width: 760, height: 380), env,
                     dir.appendingPathComponent("flip-\(name).png"))
            }
            let pill = MenuBarPill.image(minutes: "21", seconds: "14", phase: .focus, running: true, fresh: false,
                                         theme: theme)
            if let tiff = pill.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("pill-\(theme.rawValue).png"))
            }
        }
    }

    private struct Env {
        let scheme: ColorScheme
        let theme: ThemeColor
        let engine: TimerEngine
        let settings: AppSettings
        let stats: StatsStore
    }

    @MainActor
    private static func save<V: View>(_ view: V, _ env: Env, _ url: URL) {
        let content = view
            .environment(env.engine).environment(env.settings).environment(env.stats)
            .environment(\.colorScheme, env.scheme)
            .environment(\.tickTheme, env.theme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}
