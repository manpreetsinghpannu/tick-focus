import AppKit
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
    /// Why the timer stopped itself (Mac slept, screen locked), shown until you start again.
    private(set) var autoPauseNote: String?

    /// The task this focus time counts toward. Finished focus sessions add their minutes to it.
    /// Remembered across restarts.
    var workingOn: UUID? {
        didSet { UserDefaults.standard.set(workingOn?.uuidString, forKey: "workingOn") }
    }

    @ObservationIgnored private let focusMode = FocusModeController()
    @ObservationIgnored private var timer: DispatchSourceTimer?
    /// When the running session ends. Remaining time is read from the clock, so a late timer never drifts.
    @ObservationIgnored private var endDate: Date?
    /// Keeps macOS App Nap from delaying ticks while the panel is closed. Still allows the Mac to sleep.
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var tickIndex = 0
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(settings: AppSettings, stats: StatsStore, sound: SoundPlayer, tasks: TaskStore) {
        self.settings = settings
        self.stats = stats
        self.sound = sound
        self.tasks = tasks
        let focus = settings.focusMinutes * 60
        total = focus
        remaining = focus
        workingOn = UserDefaults.standard.string(forKey: "workingOn").flatMap(UUID.init(uuidString:))
        watchForAbsence()
    }

    deinit {
        for (center, token) in observers { center.removeObserver(token) }
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
    /// Never shows "Round 5 of 4" if the setting was lowered mid-cycle.
    var displayRound: Int { min(round, settings.rounds) }

    var nextPhase: Phase {
        switch phase {
        case .focus: round >= settings.rounds ? .longBreak : .shortBreak
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
        autoPauseNote = nil
        isRunning = true
        tickIndex = 0
        endDate = Date().addingTimeInterval(TimeInterval(remaining))
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Focus timer running")
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.secondElapsed() }
        t.resume()
        timer = t
        syncFocusMode()
    }

    func pause() {
        if isRunning, let endDate {
            remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
        }
        isRunning = false
        endDate = nil
        timer?.cancel()
        timer = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        syncFocusMode()
    }

    /// Do Not Disturb is on only while a focus (not break) session is actually running.
    func syncFocusMode() {
        focusMode.set(active: settings.focusModeSync && isRunning && !phase.isBreak)
    }

    /// Called when the app quits: stop, and make sure Do Not Disturb is turned back off first.
    func shutdown() {
        pause()
        focusMode.waitUntilApplied()
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
        round = min(round, settings.rounds)
        if !isRunning && isFresh { load() }
    }

    // MARK: Internals

    private func load() {
        total = duration(of: phase)
        remaining = total
    }

    /// Time only counts while someone can be at the Mac: sleeping, a dark screen, a locked
    /// screen or switching users all pause the session. You resume it yourself.
    private func watchForAbsence() {
        let workspace = NSWorkspace.shared.notificationCenter
        let reasons: [(NotificationCenter, Notification.Name, String)] = [
            (workspace, NSWorkspace.willSleepNotification, "Paused while your Mac slept."),
            (workspace, NSWorkspace.screensDidSleepNotification, "Paused when the screen turned off."),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, "Paused when you switched users."),
            (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsLocked"),
             "Paused when the screen locked."),
        ]
        for (center, name, note) in reasons {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.pause()
                self.autoPauseNote = note
            }
            observers.append((center, token))
        }
    }

    private func secondElapsed() {
        guard let endDate else { return }
        remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
        if remaining == 0 {
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
        let end = Date()
        switch phase {
        case .focus, .custom:
            // Counts even if the task was checked off mid-session.
            let task = tasks.task(workingOn)
            for (day, seconds) in Self.splitByDay(seconds: total, endingAt: end) {
                stats.recordFocus(seconds: seconds, countsAsPomodoro: phase == .focus && day == end,
                                  label: task?.title ?? "", on: day)
                if let task { tasks.log(minutes: seconds / 60, to: task.id, on: day) }
            }
        case .shortBreak, .longBreak:
            stats.recordBreak(seconds: total)
        }
        advance()
    }

    /// Splits a session ending at `end` across midnight, so 11:50 PM–12:15 AM credits each day its share.
    /// The day that holds the end is returned as `end` itself.
    static func splitByDay(seconds: Int, endingAt end: Date) -> [(Date, Int)] {
        let midnight = Calendar.current.startOfDay(for: end)
        let today = min(seconds, Int(end.timeIntervalSince(midnight)))
        let yesterday = seconds - today
        guard yesterday > 0 else { return [(end, seconds)] }
        return [(midnight.addingTimeInterval(-1), yesterday), (end, today)]
    }

    private func advance() {
        if phase == .custom {
            load()
            return
        }
        let next = nextPhase
        if phase.isBreak { round = round >= settings.rounds ? 1 : round + 1 }
        phase = next
        load()
    }
}
