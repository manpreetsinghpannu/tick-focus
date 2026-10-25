import Foundation

/// Turns Do Not Disturb on and off during focus sessions.
/// macOS has no public API for Focus, so this runs two user-made Shortcuts that each contain a "Set Focus" action.
/// Runs happen one at a time, in order, so a quick start-then-pause can't finish "On" after "Off".
final class FocusModeController {
    static let onShortcut = "On Track Focus On"
    static let offShortcut = "On Track Focus Off"

    private var active = false
    private let queue = DispatchQueue(label: "OnTrack.focusMode")

    func set(active newValue: Bool) {
        guard newValue != active else { return }
        active = newValue
        let name = newValue ? Self.onShortcut : Self.offShortcut
        queue.async { Self.runAndWait(name) }
    }

    /// Blocks until every queued on/off has finished. Used when the app quits.
    func waitUntilApplied() {
        queue.sync {}
    }

    /// Whether both shortcuts exist in the Shortcuts app.
    static func shortcutsInstalled() async -> Bool {
        await Task.detached {
            let pipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let names = Set(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init))
            return names.contains(onShortcut) && names.contains(offShortcut)
        }.value
    }

    private static func runAndWait(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }
}
