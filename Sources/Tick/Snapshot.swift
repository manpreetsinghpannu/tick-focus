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
        }
        let pill = MenuBarPill.image(minutes: "21", seconds: "14", phase: .focus, running: true, fresh: false)
        if let tiff = pill.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("pill.png"))
        }
    }

    /// Every ClockFont inside the real timer ring, dark and light, for picking a face.
    @MainActor
    static func renderFontSheet(to url: URL) {
        func sample(_ face: ClockFont, _ p: Palette) -> some View {
            let size: CGFloat = 64
            return ZStack {
                Circle().stroke(p.track, lineWidth: 10)
                Circle().trim(from: 0, to: 0.3)
                    .stroke(p.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                SplitDigits(minutes: "21", seconds: "14", size: size, color: p.accent, gapColor: p.bg,
                            maxWidth: 124, face: face)
            }
            .frame(width: 170, height: 170)
            .padding(12)
            .background(p.bg)
        }

        let rows = stride(from: 0, to: ClockFont.allCases.count, by: 3).map { Array(ClockFont.allCases[$0..<min($0 + 3, ClockFont.allCases.count)]) }
        let sheet = VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.self) { face in
                        VStack(spacing: 8) {
                            HStack(spacing: 0) { sample(face, .dark); sample(face, .light) }
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text("\((ClockFont.allCases.firstIndex(of: face) ?? 0) + 1). \(face.title)\(face == .compressed ? " (current)" : "")")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(28)
        .background(Color(hex: 0x1A1A1C))
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
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
