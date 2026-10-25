import Foundation
import Observation

enum TimerMode: String, CaseIterable {
    case pomodoro, custom
}

enum Phase {
    case focus, shortBreak, longBreak, custom

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        case .custom: "Custom timer"
        }
    }

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// Owns the countdown: phases, rounds, ticking, the start chime, the end bell and stats recording.
@Observable
final class TimerEngine {
    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored let stats: StatsStore
    @ObservationIgnored let sound: SoundPlayer
    @ObservationIgnored let tasks: TaskStore

    private(set) var mode: TimerMode = .pomodoro
    private(set) var phase: Phase = .focus
    private(set) var round = 1
    private(set) var total: Int
    private(set) var remaining: Int
    private(set) var isRunning = false
    /// The task this focus time counts toward. Finished focus sessions add their minutes to it.
    var workingOn: UUID?

    @ObservationIgnored private let focusMode = FocusModeController()
    @ObservationIgnored private var timer: DispatchSourceTimer?
    @ObservationIgnored private var tickIndex = 0

    init(settings: AppSettings, stats: StatsStore, sound: SoundPlayer, tasks: TaskStore) {
        self.settings = settings
        self.stats = stats
        self.sound = sound
        self.tasks = tasks
        let focus = settings.focusMinutes * 60
        total = focus
        remaining = focus
    }

    /// The selected task's title, or "" if none is selected (or it was deleted or completed).
    var workingOnTitle: String {
        guard let task = tasks.task(workingOn), !task.isDone else { return "" }
        return task.title
    }

    var progress: Double { total == 0 ? 0 : 1 - Double(remaining) / Double(total) }
    var isFresh: Bool { remaining == total }
    var minutesText: String { String(format: "%02d", remaining / 60) }
    var secondsText: String { String(format: "%02d", remaining % 60) }

    var nextPhase: Phase {
        switch phase {
        case .focus: round % settings.rounds == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak: .focus
        case .custom: .custom
        }
    }

    func duration(of phase: Phase) -> Int {
        switch phase {
        case .focus: settings.focusMinutes * 60
        case .shortBreak: settings.shortBreakMinutes * 60
        case .longBreak: settings.longBreakMinutes * 60
        case .custom: settings.customMinutes * 60
        }
    }

    // MARK: Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        if remaining == 0 { remaining = total }
        // The chime marks the start of a fresh focus session, not a resume.
        if isFresh && !phase.isBreak && settings.startChime { sound.playChime() }
        isRunning = true
        tickIndex = 0
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.secondElapsed() }
        t.resume()
        timer = t
        syncFocusMode()
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
        syncFocusMode()
    }

    /// Do Not Disturb is on only while a focus (not break) session is actually running.
    func syncFocusMode() {
        focusMode.set(active: settings.focusModeSync && isRunning && !phase.isBreak)
    }

    func reset() {
        pause()
        remaining = total
    }

    func skip() {
        pause()
        advance()
    }

    func setMode(_ newMode: TimerMode) {
        guard newMode != mode else { return }
        pause()
        mode = newMode
        phase = newMode == .custom ? .custom : .focus
        round = 1
        load()
    }

    /// Picks up edited durations, but never disturbs a session that's running or partly done.
    func settingsChanged() {
        if !isRunning && isFresh { load() }
    }

    // MARK: Internals

    private func load() {
        total = duration(of: phase)
        remaining = total
    }

    private func secondElapsed() {
        remaining -= 1
        if remaining <= 0 {
            remaining = 0
            finish()
            return
        }
        let level = tickLevel
        guard shouldTick, level > 0 else { return }
        sound.playTick(settings.tickSound, accent: isAccent(tickIndex), volume: settings.effectiveTickVolume * level)
        tickIndex += 1
    }

    /// 0...1 multiplier from the tick pattern. The final minute always ticks at full volume.
    private var tickLevel: Float {
        if remaining <= 60 { return 1 }
        switch settings.tickPattern {
        case .always: return 1
        case .lastMinute: return 0
        case .fade: return max(0, 1 - Float(total - remaining) / 300)
        }
    }

    private var shouldTick: Bool {
        !settings.muted && settings.tickVolume > 0 && !(phase.isBreak && settings.silentBreaks)
    }

    /// Mechanical clock alternates tick/tock; the metronome accents every 4th beat.
    private func isAccent(_ index: Int) -> Bool {
        switch settings.tickSound {
        case .mechanical: index % 2 == 1
        case .metronome: index % 4 == 0
        default: false
        }
    }

    private func finish() {
        pause()
        sound.playBell()
        switch phase {
        case .focus, .custom:
            stats.recordFocus(seconds: total, countsAsPomodoro: phase == .focus, label: workingOnTitle)
            if let id = workingOn, !workingOnTitle.isEmpty { tasks.log(minutes: total / 60, to: id) }
        case .shortBreak, .longBreak: stats.recordBreak(seconds: total)
        }
        advance()
    }

    private func advance() {
        if phase == .custom {
            load()
            return
        }
        let next = nextPhase
        if phase.isBreak { round = round % settings.rounds + 1 }
        phase = next
        load()
    }
}
