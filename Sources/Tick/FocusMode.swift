import Foundation

/// Turns Do Not Disturb on and off during focus sessions.
/// macOS has no public API for Focus, so this runs two user-made Shortcuts that each contain a "Set Focus" action.
final class FocusModeController {
    static let onShortcut = "Tick Focus On"
    static let offShortcut = "Tick Focus Off"

    private var active = false

    func set(active newValue: Bool) {
        guard newValue != active else { return }
        active = newValue
        run(newValue ? Self.onShortcut : Self.offShortcut)
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

    private func run(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
