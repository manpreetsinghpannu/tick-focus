import SwiftUI

/// "1h 10m", "2h", "45m".
func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m)m" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

/// "2h", "1.5h", "0h" — for the small day cells.
private func shortHours(_ minutes: Int) -> String {
    minutes % 60 == 0 ? "\(minutes / 60)h" : String(format: "%.1fh", Double(minutes) / 60)
}

struct TasksTab: View {
    var onWorkOn: () -> Void = {}
    @State var openTaskID: UUID?
    @State private var listMenuOpen = false
    @State private var sortMenuOpen = false
    @State private var newTask = ""
    @Environment(TaskStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let id = openTaskID, store.task(id) != nil {
            TaskDetailView(taskID: id, onBack: { openTaskID = nil }, onWorkOn: onWorkOn)
        } else {
            list
        }
    }

    private var list: some View {
        let p = Palette.of(scheme)
        return VStack(alignment: .leading, spacing: 10) {
            header
            HStack(spacing: 8) {
                Image(systemName: "plus").foregroundStyle(p.muted)
                if Snapshot.isRendering {
                    Text("Add task").foregroundStyle(p.muted)
                } else {
                    TextField("Add task", text: $newTask)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            store.addTask(newTask)
                            newTask = ""
                        }
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(p.card, in: RoundedRectangle(cornerRadius: 9))

            PanelScroll {
                VStack(alignment: .leading, spacing: 2) {
                    let tasks = store.visibleTasks
                    if tasks.isEmpty {
                        Text("Add your first task above. Give it an hours goal to track daily time.")
                            .font(.system(size: 12))
                            .foregroundStyle(p.muted)
                            .padding(.top, 8)
                    } else if store.grouping == .goal {
                        section("Hours goals", tasks.filter { $0.goal != nil })
                        section("Other", tasks.filter { $0.goal == nil })
                    } else {
                        ForEach(tasks) { row($0) }
                    }
                }
            }
        }
        .foregroundStyle(p.text)
        .overlay {
            if listMenuOpen || sortMenuOpen {
                Color.black.opacity(0.001)
                    .onTapGesture { listMenuOpen = false; sortMenuOpen = false }
            }
        }
        .overlay(alignment: .topLeading) {
            if listMenuOpen { ListMenu(close: { listMenuOpen = false }).offset(y: 34) }
        }
        .overlay(alignment: .topTrailing) {
            if sortMenuOpen { SortMenu().offset(y: 34) }
        }
    }

    private var header: some View {
        let p = Palette.of(scheme)
        return HStack {
            Button { listMenuOpen.toggle(); sortMenuOpen = false } label: {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill").font(.system(size: 15))
                    Text(store.selectedList?.name ?? "Tasks").font(.system(size: 19, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(p.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button { sortMenuOpen.toggle(); listMenuOpen = false } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(p.tonal, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Group and sort")
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.of(scheme).muted)
                .padding(.top, 6)
            ForEach(tasks) { row($0) }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(task: task, open: { openTaskID = task.id }, workOn: onWorkOn)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let open: () -> Void
    let workOn: () -> Void
    @Environment(TaskStore.self) private var store
    @Environment(TimerEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        HStack(spacing: 10) {
            Button {
                store.update(task.id) { $0.isDone.toggle() }
            } label: {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(task.isDone ? p.muted : p.muted)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 14))
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? p.muted : p.text)
                .lineLimit(1)
            if engine.workingOn == task.id && !task.isDone {
                Image(systemName: "timer").font(.system(size: 10)).foregroundStyle(p.muted)
            }
            Spacer(minLength: 4)
            if !task.isDone, let chip = chip(p) { chip }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .contextMenu {
            Button("Work on this") { engine.workingOn = task.id; workOn() }
            Button("Open") { open() }
            Divider()
            Button("Move up") { store.move(task.id, up: true) }
            Button("Move down") { store.move(task.id, up: false) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(task.id) }
        }
    }

    private func chip(_ p: Palette) -> AnyView? {
        guard task.goal != nil else { return nil }
        guard let today = task.today else {
            return AnyView(GoalChip(text: "\(Int((task.goalProgress * 100).rounded()))%", fill: p.tonal, color: p.text))
        }
        let text = "\(formatMinutes(today.worked)) / \(formatMinutes(today.target))"
        switch today.status {
        case .done: return AnyView(GoalChip(text: text, fill: p.done, color: .white))
        case .rest: return AnyView(GoalChip(text: "Rest day", fill: p.tonal, color: p.muted))
        default: return AnyView(GoalChip(text: text, fill: p.tonal, color: p.text))
        }
    }
}

struct GoalChip: View {
    let text: String
    let fill: Color
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(fill, in: Capsule())
    }
}

// MARK: - Menus

private struct MenuCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 2) { content }
            .padding(6)
            .frame(width: 210)
            .background(p.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

private struct MenuRow: View {
    let title: String
    var icon: String?
    var checked = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).frame(width: 16).foregroundStyle(p.muted) }
                Text(title)
                Spacer()
                if checked { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            }
            .font(.system(size: 13))
            .foregroundStyle(p.text)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(checked ? p.tonal : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MenuHeading: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.of(scheme).muted)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }
}

private struct ListMenu: View {
    let close: () -> Void
    @State private var newList = ""
    @Environment(TaskStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        MenuCard {
            ForEach(store.lists) { list in
                MenuRow(title: list.name, icon: "book.closed", checked: list.id == store.selectedListID) {
                    store.selectedListID = list.id
                    close()
                }
                .contextMenu {
                    if store.lists.count > 1 {
                        Button("Delete list and its tasks", role: .destructive) { store.deleteList(list.id) }
                    }
                }
            }
            Rectangle().fill(p.border).frame(height: 0.5).padding(.vertical, 3)
            HStack(spacing: 8) {
                Image(systemName: "plus").frame(width: 16).foregroundStyle(p.muted)
                if Snapshot.isRendering {
                    Text("New list").foregroundStyle(p.muted)
                } else {
                    TextField("New list", text: $newList)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            store.addList(named: newList)
                            newList = ""
                            close()
                        }
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(height: 28)
        }
    }
}

private struct SortMenu: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        MenuCard {
            MenuHeading(text: "Group by")
            ForEach(TaskGrouping.allCases, id: \.self) { g in
                MenuRow(title: g.title, icon: "rectangle.grid.1x2", checked: store.grouping == g) { store.grouping = g }
            }
            MenuHeading(text: "Sort by")
            ForEach(TaskSort.allCases, id: \.self) { s in
                MenuRow(title: s.title, icon: "line.3.horizontal.decrease", checked: store.sort == s) { store.sort = s }
            }
        }
    }
}

// MARK: - Task detail and hours goal

struct TaskDetailView: View {
    let taskID: UUID
    let onBack: () -> Void
    let onWorkOn: () -> Void
    @State var selectedDay: Int?
    @State private var totalHours = 20.0
    @State private var days = 10
    @Environment(TaskStore.self) private var store
    @Environment(TimerEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        if let task = store.task(taskID) {
            PanelScroll {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                            Text(store.selectedList?.name ?? "Tasks")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(p.muted)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(p.text)

                    Button {
                        engine.workingOn = task.id
                        onWorkOn()
                    } label: {
                        Label(engine.workingOn == task.id ? "Working on this" : "Work on this", systemImage: "timer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(p.onAccent)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(p.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if let goal = task.goal {
                        goalView(task, goal, p)
                    } else {
                        goalSetup(p)
                    }

                    HStack(spacing: 16) {
                        if task.goal != nil {
                            Button("Remove goal") { store.update(task.id) { $0.goal = nil }; selectedDay = nil }
                        }
                        Button("Delete task") { onBack(); store.delete(task.id) }
                            .foregroundStyle(p.missed)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(p.muted)
                    .padding(.top, 4)
                }
            }
        }
    }

    // Asks for total hours and days, then spreads them evenly as a starting point.
    private func goalSetup(_ p: Palette) -> some View {
        Box {
            Text("Hours goal").fontWeight(.semibold)
            stepperRow("Total hours", value: "\(Int(totalHours))h",
                       minus: { totalHours = max(1, totalHours - 1) }, plus: { totalHours = min(1000, totalHours + 1) }, p)
            stepperRow("Days", value: "\(days)",
                       minus: { days = max(1, days - 1) }, plus: { days = min(365, days + 1) }, p)
            let perDay = Int((totalHours * 60 / Double(days)).rounded())
            Text("About \(formatMinutes(perDay)) a day, starting today. You can change any single day after.")
                .font(.system(size: 11))
                .foregroundStyle(p.muted)
            Button {
                store.update(taskID) { $0.goal = HourGoal(totalHours: totalHours, days: days) }
            } label: {
                Text("Set goal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(p.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(p.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func goalView(_ task: TaskItem, _ goal: HourGoal, _ p: Palette) -> some View {
        let statuses = (0..<goal.days).map { task.status(ofDay: $0) }
        let past = statuses.filter { $0 == .done || $0 == .missed }
        let hit = statuses.filter { $0 == .done }.count
        let todayIndex = goal.dayIndex(of: Date())

        return Box {
            HStack {
                Text("Hours goal").fontWeight(.semibold)
                Spacer()
                Text("\(formatMinutes(goal.totalMinutes)) over \(goal.days) days")
                    .font(.system(size: 11)).foregroundStyle(p.muted)
            }
            Text(todayIndex.map { "Day \($0 + 1) of \(goal.days) · \(hit) of \(past.count) days hit" }
                 ?? "\(hit) of \(goal.days) days hit")
                .font(.system(size: 11)).foregroundStyle(p.muted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.track)
                    Capsule().fill(p.done).frame(width: geo.size.width * min(task.goalProgress, 1))
                }
            }
            .frame(height: 6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<goal.days, id: \.self) { i in
                    DayCell(task: task, goal: goal, index: i, status: statuses[i], selected: selectedDay == i)
                        .onTapGesture { selectedDay = selectedDay == i ? nil : i }
                }
            }

            HStack(spacing: 10) {
                legend(p.done, "Done")
                legend(p.missed, "Missed")
                legend(p.tonal, "Today")
            }
            .font(.system(size: 10))
            .foregroundStyle(p.muted)

            if let i = selectedDay, goal.dailyMinutes.indices.contains(i) {
                dayEditor(task, goal, i, p)
            } else {
                Text("Tap a day to change its hours.")
                    .font(.system(size: 11)).foregroundStyle(p.muted)
            }
        }
    }

    private func dayEditor(_ task: TaskItem, _ goal: HourGoal, _ i: Int, _ p: Palette) -> some View {
        let date = goal.date(ofDay: i)
        let target = goal.dailyMinutes[i]
        return VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(p.border).frame(height: 0.5)
            Text(date.formatted(.dateTime.weekday(.wide).day().month()))
                .font(.system(size: 12, weight: .semibold))
            stepperRow("Target", value: formatMinutes(target),
                       minus: { setTarget(i, max(0, target - 15)) },
                       plus: { setTarget(i, min(24 * 60, target + 15)) }, p)
            Text("Worked \(formatMinutes(task.loggedMinutes(on: date)))\(target == 0 ? " · rest day" : "")")
                .font(.system(size: 11)).foregroundStyle(p.muted)
        }
    }

    private func setTarget(_ day: Int, _ minutes: Int) {
        store.update(taskID) { $0.goal?.dailyMinutes[day] = minutes }
    }

    private func stepperRow(_ title: String, value: String, minus: @escaping () -> Void,
                            plus: @escaping () -> Void, _ p: Palette) -> some View {
        HStack {
            Text(title)
            Spacer()
            stepButton("minus", minus, p)
            Text(value).fontWeight(.semibold).monospacedDigit().frame(minWidth: 56)
            stepButton("plus", plus, p)
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void, _ p: Palette) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(p.text)
                .frame(width: 22, height: 22)
                .background(p.tonal, in: Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

/// One day of an hours goal: Cobalt when done, Brick when the day ended short,
/// grey progress for today, dashed outline for days still ahead.
private struct DayCell: View {
    let task: TaskItem
    let goal: HourGoal
    let index: Int
    let status: DayStatus
    let selected: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        let date = goal.date(ofDay: index)
        let worked = task.loggedMinutes(on: date)
        let target = goal.dailyMinutes[index]

        VStack(spacing: 1) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 9, weight: .medium))
                .opacity(0.75)
            Text(status == .upcoming ? shortHours(target) : (status == .rest ? "rest" : shortHours(worked)))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(foreground(p))
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background {
            switch status {
            case .done: RoundedRectangle(cornerRadius: 7).fill(p.done)
            case .missed: RoundedRectangle(cornerRadius: 7).fill(p.missed)
            case .inProgress:
                RoundedRectangle(cornerRadius: 7).fill(p.tonal)
                    .overlay(alignment: .bottom) {
                        GeometryReader { geo in
                            Rectangle().fill(p.muted.opacity(0.35))
                                .frame(height: geo.size.height * min(Double(worked) / Double(max(target, 1)), 1))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            case .upcoming, .rest:
                RoundedRectangle(cornerRadius: 7).strokeBorder(p.border, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.text, lineWidth: selected ? 2 : 0))
        .contentShape(Rectangle())
    }

    private func foreground(_ p: Palette) -> Color {
        switch status {
        case .done, .missed: .white
        case .inProgress: p.text
        case .upcoming, .rest: p.muted
        }
    }
}
