import SwiftUI

struct SettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme
    @State var soundListOpen = false
    @State private var shortcutsReady: Bool?

    var body: some View {
        PanelScroll { content }
    }

    private var content: some View {
        @Bindable var settings = settings
        let p = Palette.of(scheme)

        return VStack(alignment: .leading, spacing: 10) {
            TabTitle(text: "Settings")

            HStack(spacing: 6) {
                MinutesTile(title: "Focus", value: $settings.focusMinutes, range: 1...120)
                MinutesTile(title: "Short break", value: $settings.shortBreakMinutes, range: 1...60)
                MinutesTile(title: "Long break", value: $settings.longBreakMinutes, range: 1...90)
            }

            Box {
                HStack {
                    Text("Rounds before long break")
                    Spacer()
                    Text("\(settings.rounds)").fontWeight(.semibold).foregroundStyle(p.accent)
                }
                BlueSlider(value: Binding(get: { Double(settings.rounds) },
                                          set: { settings.rounds = Int($0) }),
                           range: 2...8, step: 1)
                HStack {
                    Text("Daily goal")
                    Spacer()
                    stepButton("minus") { settings.dailyGoal = max(1, settings.dailyGoal - 1) }
                    Text("\(settings.dailyGoal) pomodoros")
                        .fontWeight(.semibold)
                        .foregroundStyle(p.accent)
                        .frame(minWidth: 86)
                    stepButton("plus") { settings.dailyGoal = min(24, settings.dailyGoal + 1) }
                }
            }

            Box {
                HStack {
                    Text("Tick sound")
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { soundListOpen.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(settings.tickSound.title).fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(soundListOpen ? 180 : 0))
                        }
                        .foregroundStyle(p.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(p.tonal, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button { preview(settings.tickSound) } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(p.accent)
                            .frame(width: 24, height: 24)
                            .background(p.tonal, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Preview")
                }
                if soundListOpen {
                    VStack(spacing: 2) {
                        ForEach(TickSound.allCases) { sound in
                            Button {
                                settings.tickSound = sound
                                preview(sound)
                                withAnimation(.easeOut(duration: 0.15)) { soundListOpen = false }
                            } label: {
                                HStack {
                                    Text(sound.title)
                                    Spacer()
                                    if sound == settings.tickSound {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .foregroundStyle(sound == settings.tickSound ? p.accent : p.text)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(sound == settings.tickSound ? p.tonal : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(p.bg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.border, lineWidth: 0.5))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                HStack(spacing: 8) {
                    Button { settings.muted.toggle() } label: {
                        Image(systemName: settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(settings.muted ? p.muted : p.accent)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    .help(settings.muted ? "Unmute ticking" : "Mute ticking")
                    BlueSlider(value: Binding(get: { settings.tickVolume },
                                              set: { settings.tickVolume = $0; settings.muted = false }),
                               range: 0...1, dimmed: settings.muted)
                    Text("\(Int((settings.tickVolume * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(p.muted)
                        .frame(width: 34, alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ticking")
                    Segmented(options: TickPattern.allCases.map { ($0, $0.title) },
                              selection: $settings.tickPattern)
                    Text(tickPatternHint)
                        .font(.system(size: 10))
                        .foregroundStyle(p.muted)
                }
                Toggle("Silent during breaks", isOn: $settings.silentBreaks)
                Toggle("Soft chime when focus starts", isOn: $settings.startChime)
            }
            .toggleStyle(BlueSwitch())

            Box {
                Toggle("Do Not Disturb during focus", isOn: $settings.focusModeSync)
                if settings.focusModeSync && shortcutsReady == false {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One-time setup: in the Shortcuts app, make two shortcuts named \"\(FocusModeController.onShortcut)\" (Set Focus: Do Not Disturb, On) and \"\(FocusModeController.offShortcut)\" (Set Focus: Do Not Disturb, Off).")
                            .font(.system(size: 11))
                            .foregroundStyle(p.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Open Shortcuts") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                            }
                            Button("Check again") { Task { shortcutsReady = await FocusModeController.shortcutsInstalled() } }
                        }
                        .controlSize(.small)
                    }
                } else if settings.focusModeSync && shortcutsReady == true {
                    Label("Shortcuts found. Focus turns on while you work.", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(p.muted)
                }
            }
            .toggleStyle(BlueSwitch())
            .task { shortcutsReady = await FocusModeController.shortcutsInstalled() }

            Box {
                HStack {
                    Text("Appearance")
                    Spacer()
                    Segmented(options: Appearance.allCases.map { ($0, $0.title) },
                              selection: $settings.appearance)
                }
                Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.setLaunchAtLogin($0) }))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.system(size: 11)).foregroundStyle(.red)
                }
                HStack {
                    Text("Start / pause hotkey")
                    Spacer()
                    Text("⌥⌘P")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(p.tonal, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .toggleStyle(BlueSwitch())

            Button { NSApp.terminate(nil) } label: {
                Text("Quit Tick Focus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onChange(of: settings.focusMinutes) { engine.settingsChanged() }
        .onChange(of: settings.shortBreakMinutes) { engine.settingsChanged() }
        .onChange(of: settings.longBreakMinutes) { engine.settingsChanged() }
        .onChange(of: settings.focusModeSync) { engine.syncFocusMode() }
    }

    private var tickPatternHint: String {
        switch settings.tickPattern {
        case .always: "Ticks every second of a session."
        case .lastMinute: "Quiet until the final minute, then ticks."
        case .fade: "Fades to silence over 5 minutes, returns for the last minute."
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        let p = Palette.of(scheme)
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(p.accent)
                .frame(width: 22, height: 22)
                .background(p.tonal, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func preview(_ sound: TickSound) {
        let volume = max(settings.effectiveTickVolume, 0.3)
        engine.sound.playTick(sound, accent: false, volume: volume)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            engine.sound.playTick(sound, accent: true, volume: volume)
        }
    }
}

private struct MinutesTile: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundStyle(p.muted)
            HStack(spacing: 0) {
                step("chevron.left") { value = max(range.lowerBound, value - 1) }
                Text(String(format: "%02d", value))
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(p.text)
                    .frame(maxWidth: .infinity)
                step("chevron.right") { value = min(range.upperBound, value + 1) }
            }
            .padding(.vertical, 4)
            .background(p.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func step(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.of(scheme).muted)
                .frame(width: 16, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}
