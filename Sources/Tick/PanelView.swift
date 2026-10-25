import SwiftUI

enum PanelTab: CaseIterable {
    case timer, stats, settings

    var title: String {
        switch self {
        case .timer: "Timer"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .timer: "hourglass"
        case .stats: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// The dropdown shown from the menu bar.
struct PanelView: View {
    var openFocusWindow: () -> Void = {}
    @State var tab: PanelTab = .timer
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tickTheme) private var theme

    var body: some View {
        let p = Palette.of(scheme, theme)
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .timer: TimerTab(openFocusWindow: openFocusWindow)
                case .stats: StatsTab()
                case .settings: SettingsTab()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Rectangle().fill(p.border).frame(height: 0.5)
            HStack {
                ForEach(PanelTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(tab == item ? p.accent : p.muted)
                                .frame(width: 44, height: 22)
                                .background(tab == item ? p.track : .clear, in: Capsule())
                            Text(item.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(tab == item ? p.text : p.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(14)
        .frame(width: 320, height: 540)
        .background(p.bg)
    }
}

struct TimerTab: View {
    var openFocusWindow: () -> Void
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tickTheme) private var theme

    var body: some View {
        let p = Palette.of(scheme, theme)
        let accent = p.accent(for: engine.phase)
        let mode = Binding(get: { engine.mode }, set: { engine.setMode($0) })

        VStack(spacing: 8) {
            HStack {
                Segmented(options: [(TimerMode.pomodoro, "Pomodoro"), (.custom, "Custom")], selection: mode)
                Spacer()
                Button(action: openFocusWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(p.muted)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open flip clock focus window")
            }

            TabTitle(text: engine.phase.title, color: accent)
            if engine.mode == .pomodoro {
                Text("Round \(engine.round) of \(settings.rounds)")
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
            }
            SessionLabelField()

            ZStack {
                Circle().stroke(p.track(for: engine.phase), lineWidth: 12)
                if engine.progress > 0.003 {
                    Circle()
                        .trim(from: 0, to: engine.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: engine.progress)
                }
                SplitDigits(minutes: engine.minutesText, seconds: engine.secondsText,
                            size: 68, color: accent, gapColor: p.bg)
            }
            .frame(width: 184, height: 184)
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                Button(action: engine.toggle) {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(p.onAccent)
                        .frame(width: engine.isRunning ? 64 : 52, height: 44)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Start or pause (⌥⌘P)")
                .animation(.easeOut(duration: 0.15), value: engine.isRunning)

                Button(action: engine.reset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(p.text)
                        .frame(width: 44, height: 44)
                        .background(p.tonal, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Reset")

                Button(action: engine.skip) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(p.text)
                        .frame(width: 36, height: 44)
                        .background(p.tonal, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Skip")
            }

            if engine.mode == .custom {
                CustomMinutesRow()
                    .padding(.top, 6)
            } else {
                VStack(spacing: 0) {
                    Text("Up next").font(.system(size: 11)).foregroundStyle(p.muted)
                    let next = engine.duration(of: engine.nextPhase)
                    Text(String(format: "%02d %02d", next / 60, next % 60))
                        .font(DigitFont.font(22))
                        .foregroundStyle(p.accent)
                    Text(engine.nextPhase.title).font(.system(size: 11)).foregroundStyle(p.muted)
                }
                .padding(.top, 4)
            }
        }
    }
}

/// "What are you working on?" — the label is saved with the session in stats.
private struct SessionLabelField: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tickTheme) private var theme

    var body: some View {
        @Bindable var engine = engine
        let p = Palette.of(scheme, theme)
        Group {
            if Snapshot.isRendering {
                Text(engine.label.isEmpty ? "What are you working on?" : engine.label)
                    .foregroundStyle(engine.label.isEmpty ? p.muted : p.text)
            } else {
                TextField("What are you working on?", text: $engine.label)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(p.text)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(width: 220, height: 26)
        .background(p.tonal, in: Capsule())
    }
}

private struct CustomMinutesRow: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tickTheme) private var theme

    var body: some View {
        let p = Palette.of(scheme, theme)
        HStack(spacing: 10) {
            stepButton("minus") { settings.customMinutes = max(1, settings.customMinutes - (settings.customMinutes > 10 ? 5 : 1)) }
            Text("\(settings.customMinutes) min")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(p.text)
                .frame(minWidth: 70)
            stepButton("plus") { settings.customMinutes = min(180, settings.customMinutes + (settings.customMinutes >= 10 ? 5 : 1)) }
        }
        .opacity(engine.isFresh && !engine.isRunning ? 1 : 0.4)
        .disabled(!(engine.isFresh && !engine.isRunning))
        .onChange(of: settings.customMinutes) { engine.settingsChanged() }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        let p = Palette.of(scheme, theme)
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(p.accent)
                .frame(width: 30, height: 30)
                .background(p.tonal, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
