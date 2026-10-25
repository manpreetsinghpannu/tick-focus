import AppKit
import Observation
import ServiceManagement

enum TickSound: String, CaseIterable, Identifiable {
    case mechanical, softClick, metronome, waterDrop, digitalBeep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mechanical: "Mechanical clock"
        case .softClick: "Soft click"
        case .metronome: "Metronome"
        case .waterDrop: "Water drop"
        case .digitalBeep: "Digital beep"
        }
    }
}

/// How much of a session ticks. The last minute always ticks, so you hear time running out.
enum TickPattern: String, CaseIterable {
    case always, lastMinute, fade

    var title: String {
        switch self {
        case .always: "Every second"
        case .lastMinute: "Last minute"
        case .fade: "Fade out"
        }
    }
}

enum Appearance: String, CaseIterable {
    case system, light, dark

    var title: String { rawValue.capitalized }
}

/// User preferences, persisted to UserDefaults on every change.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard

    var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: "focusMinutes") } }
    var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: "shortBreakMinutes") } }
    var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: "longBreakMinutes") } }
    var rounds: Int { didSet { defaults.set(rounds, forKey: "rounds") } }
    var customMinutes: Int { didSet { defaults.set(customMinutes, forKey: "customMinutes") } }

    var tickSound: TickSound { didSet { defaults.set(tickSound.rawValue, forKey: "tickSound") } }
    var tickVolume: Double { didSet { defaults.set(tickVolume, forKey: "tickVolume") } }
    var muted: Bool { didSet { defaults.set(muted, forKey: "muted") } }
    var silentBreaks: Bool { didSet { defaults.set(silentBreaks, forKey: "silentBreaks") } }
    var startChime: Bool { didSet { defaults.set(startChime, forKey: "startChime") } }
    var tickPattern: TickPattern { didSet { defaults.set(tickPattern.rawValue, forKey: "tickPattern") } }
    var dailyGoal: Int { didSet { defaults.set(dailyGoal, forKey: "dailyGoal") } }
    var focusModeSync: Bool { didSet { defaults.set(focusModeSync, forKey: "focusModeSync") } }

    var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }

    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginError: String?

    init() {
        defaults.register(defaults: [
            "focusMinutes": 25, "shortBreakMinutes": 5, "longBreakMinutes": 15, "rounds": 4,
            "customMinutes": 10, "tickSound": TickSound.mechanical.rawValue, "tickVolume": 0.6,
            "muted": false, "silentBreaks": true, "startChime": true,
            "appearance": Appearance.system.rawValue, "tickPattern": TickPattern.always.rawValue,
            "dailyGoal": 8, "focusModeSync": false,
        ])
        focusMinutes = defaults.integer(forKey: "focusMinutes")
        shortBreakMinutes = defaults.integer(forKey: "shortBreakMinutes")
        longBreakMinutes = defaults.integer(forKey: "longBreakMinutes")
        rounds = defaults.integer(forKey: "rounds")
        customMinutes = defaults.integer(forKey: "customMinutes")
        tickSound = TickSound(rawValue: defaults.string(forKey: "tickSound") ?? "") ?? .mechanical
        tickVolume = defaults.double(forKey: "tickVolume")
        muted = defaults.bool(forKey: "muted")
        silentBreaks = defaults.bool(forKey: "silentBreaks")
        startChime = defaults.bool(forKey: "startChime")
        tickPattern = TickPattern(rawValue: defaults.string(forKey: "tickPattern") ?? "") ?? .always
        dailyGoal = defaults.integer(forKey: "dailyGoal")
        focusModeSync = defaults.bool(forKey: "focusModeSync")
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
    }

    /// Perceptual volume curve, so the slider's midpoint sounds like half volume.
    var effectiveTickVolume: Float {
        muted ? 0 : Float(min(1, tickVolume * tickVolume * 1.4))
    }

    func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't change this. Move On Track to Applications and try again."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
