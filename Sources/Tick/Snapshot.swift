import AppKit
import SwiftUI

/// `Tick --snapshot <dir>` renders every screen in light and dark mode to PNGs, for checking the visuals.
enum Snapshot {
    @MainActor static var isRendering = false

    @MainActor
    static func run(into dir: URL) {
        isRendering = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = AppSettings()
        let stats = StatsStore(inMemory: true)
        stats.seedSample()
        let tasks = TaskStore(inMemory: true)
        tasks.seedSample()
        let engine = TimerEngine(settings: settings, stats: stats, sound: SoundPlayer(), tasks: tasks)
        let practice = tasks.tasks.first { $0.title == "ACCA Practice" }!
        engine.workingOn = practice.id

        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            let bg = Palette.of(scheme).bg
            let env = Env(scheme: scheme, engine: engine, settings: settings, stats: stats, tasks: tasks)
            save(PanelView(tab: .tasks), env, dir.appendingPathComponent("tasks-\(name).png"))
            save(PanelView(tab: .timer), env, dir.appendingPathComponent("timer-\(name).png"))
            // Detail, Stats and Settings scroll in the app; render them full length here.
            save(TaskDetailView(taskID: practice.id, onBack: {}, onWorkOn: {}, selectedDay: 13)
                    .padding(14).frame(width: 320).background(bg), env,
                 dir.appendingPathComponent("task-detail-\(name).png"))
            save(StatsTab().padding(14).frame(width: 320).background(bg), env,
                 dir.appendingPathComponent("stats-\(name).png"))
            save(SettingsTab(soundListOpen: false).padding(14).frame(width: 320).background(bg), env,
                 dir.appendingPathComponent("settings-\(name).png"))
            save(FlipClockView().frame(width: 760, height: 380), env,
                 dir.appendingPathComponent("flip-\(name).png"))
        }
        let pill = MenuBarPill.image(minutes: "21", seconds: "14", phase: .focus, running: true, fresh: false)
        if let tiff = pill.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("pill.png"))
        }
    }

    private struct Env {
        let scheme: ColorScheme
        let engine: TimerEngine
        let settings: AppSettings
        let stats: StatsStore
        let tasks: TaskStore
    }

    @MainActor
    private static func save<V: View>(_ view: V, _ env: Env, _ url: URL) {
        let content = view
            .environment(env.engine).environment(env.settings).environment(env.stats).environment(env.tasks)
            .environment(\.colorScheme, env.scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}
