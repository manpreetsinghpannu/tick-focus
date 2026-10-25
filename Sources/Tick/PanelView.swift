import SwiftUI

enum PanelTab: CaseIterable {
    case tasks, timer, stats, settings

    var title: String {
        switch self {
        case .tasks: "Tasks"
        case .timer: "Timer"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .tasks: "checkmark.square"
        case .timer: "timer"
        case .stats: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

/// The dropdown shown from the menu bar.
struct PanelView: View {
    var openFocusWindow: () -> Void = {}
    @State var tab: PanelTab = .timer
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .tasks: TasksTab(onWorkOn: { tab = .timer })
                case .timer: TimerTab(openFocusWindow: openFocusWindow)
                case .stats: StatsTab()
                case .settings: SettingsTab()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Rectangle().fill(p.border).frame(height: 0.5)
            // Four equal, icon-only tabs.
            HStack(spacing: 0) {
                ForEach(PanelTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 22, height: 22)
                            .foregroundStyle(tab == item ? p.text : p.muted)
                            .frame(width: 48, height: 32)
                            .background(tab == item ? p.tonal : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
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

    var body: some View {
        let p = Palette.of(scheme)
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
            WorkingOnPicker()

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

/// Picks which task this focus time counts toward. Finished focus sessions log their minutes to it.
private struct WorkingOnPicker: View {
    @State private var open = false
    @Environment(TimerEngine.self) private var engine
    @Environment(TaskStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        let task = store.task(engine.workingOn).flatMap { $0.isDone ? nil : $0 }
        VStack(spacing: 3) {
            Button { open.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.square").font(.system(size: 11))
                    Text(task.map { $0.title } ?? "Choose a task")
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(task == nil ? p.muted : p.text)
                .padding(.horizontal, 12)
                .frame(maxWidth: 230)
                .frame(height: 26)
                .background(p.tonal, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            if let today = task?.today {
                Text(today.status == .done
                     ? "\(formatMinutes(today.worked)) today · goal done"
                     : "\(formatMinutes(today.worked)) of \(formatMinutes(today.target)) today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(today.status == .done ? p.done : p.muted)
            }
        }
        .overlay(alignment: .top) {
            if open {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.openTasks) { item in
                        pickRow(item.title, chip: item.today.map { "\(formatMinutes($0.worked)) / \(formatMinutes($0.target))" },
                                done: item.today?.status == .done, selected: item.id == engine.workingOn, p) {
                            engine.workingOn = item.id
                            open = false
                        }
                    }
                    if store.openTasks.isEmpty {
                        Text("Add tasks in the Tasks tab.").font(.system(size: 12)).foregroundStyle(p.muted).padding(8)
                    }
                    pickRow("None", chip: nil, done: false, selected: engine.workingOn == nil, p) {
                        engine.workingOn = nil
                        open = false
                    }
                }
                .padding(6)
                .frame(width: 240)
                .background(p.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .offset(y: 30)
            }
        }
        .zIndex(1)
    }

    private func pickRow(_ title: String, chip: String?, done: Bool, selected: Bool, _ p: Palette,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                if let chip { GoalChip(text: chip, fill: done ? p.done : p.tonal, color: done ? .white : p.text) }
                if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            }
            .font(.system(size: 13))
            .foregroundStyle(p.text)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(selected ? p.tonal : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CustomMinutesRow: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
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
        let p = Palette.of(scheme)
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
