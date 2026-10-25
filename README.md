# Tick Focus

A menu bar Pomodoro timer for macOS that ticks every second until time's up.

## Build and run

```bash
./build.sh            # builds "build/Tick Focus.app"
open "build/Tick Focus.app"
./build.sh --install  # builds and copies to /Applications (needed for Launch at login)
```

Requires macOS 14+ and the Swift command-line tools (Xcode not needed).

## Using it

- Click the pill in the menu bar to open the panel (Timer, Stats, Settings). Right-click it for Start/Pause, Skip, Reset and Quit.
- ⌥⌘P starts or pauses from anywhere. Space works in the focus window.
- Tasks tab: lists, tasks, and hours goals (total hours over N days, spread evenly, any day editable). Days turn Cobalt when done and Brick when a day ends short.
- Pick a task under "Working on" on the Timer; finished focus sessions add their minutes to it.
- Do Not Disturb during focus needs two Shortcuts named "Tick Focus On" and "Tick Focus Off", each with a Set Focus action.
- The expand icon on the Timer tab opens the flip clock focus window (resizable, can go fullscreen).
- Quit from the bottom of the Settings tab.

All sounds (five tick styles, the start chime, the end bell) are synthesized in `Sources/Tick/Synth.swift`.
Stats are stored in `~/Library/Application Support/Tick/stats.json`.

`Tick --snapshot <dir>` renders every screen in light and dark mode to PNGs.

## License

MIT. See [LICENSE](LICENSE).
