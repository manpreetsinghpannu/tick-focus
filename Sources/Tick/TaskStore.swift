import Foundation
import Observation

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func of(_ date: Date) -> String { formatter.string(from: date) }
}

/// Moves a data file that couldn't be read out of the way (e.g. stats.unreadable-1761400000.json),
/// so the next save starts a fresh file instead of overwriting the old data.
func setAsideUnreadable(_ url: URL) {
    let stamp = Int(Date().timeIntervalSince1970)
    let name = url.deletingPathExtension().lastPathComponent + ".unreadable-\(stamp).json"
    try? FileManager.default.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(name))
}

struct TaskList: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
}

/// "Work X hours over N days": one target per day, starting on `startDate`.
struct HourGoal: Codable, Hashable {
    var startDate: Date
    var dailyMinutes: [Int]

    var days: Int { dailyMinutes.count }
    var totalMinutes: Int { dailyMinutes.reduce(0, +) }

    /// Spreads the total evenly in 5-minute steps; any remainder goes to the earliest days.
    init(totalHours: Double, days: Int, start: Date = Date()) {
        let total = Int((totalHours * 60).rounded())
        let days = max(days, 1)
        let base = total / days / 5 * 5
        var leftover = total - base * days
        var minutes = Array(repeating: base, count: days)
        var i = 0
        while leftover > 0 {
            let step = min(5, leftover)
            minutes[i % days] += step
            leftover -= step
            i += 1
        }
        startDate = Calendar.current.startOfDay(for: start)
        dailyMinutes = minutes
    }

    func date(ofDay index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startDate)!
    }

    func dayIndex(of date: Date) -> Int? {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: startDate, to: cal.startOfDay(for: date)).day ?? -1
        return dailyMinutes.indices.contains(days) ? days : nil
    }
}

enum DayStatus {
    case done, missed, inProgress, upcoming, rest
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var listID: UUID
    var title: String
    var isDone = false
    var order: Int
    var goal: HourGoal?
    /// Focus minutes logged per day ("2026-10-25" → 70).
    var logged: [String: Int] = [:]

    func loggedMinutes(on date: Date) -> Int { logged[DayKey.of(date)] ?? 0 }

    func status(ofDay index: Int, today: Date = Date()) -> DayStatus {
        guard let goal else { return .upcoming }
        let date = goal.date(ofDay: index)
        let target = goal.dailyMinutes[index]
        let worked = loggedMinutes(on: date)
        let cal = Calendar.current
        if target == 0 { return .rest }
        if worked >= target { return .done }
        if cal.isDate(date, inSameDayAs: today) { return .inProgress }
        return date < today ? .missed : .upcoming
    }

    /// Today's target and progress, if the goal covers today.
    var today: (worked: Int, target: Int, status: DayStatus)? {
        guard let goal, let i = goal.dayIndex(of: Date()) else { return nil }
        return (loggedMinutes(on: Date()), goal.dailyMinutes[i], status(ofDay: i))
    }

    var goalProgress: Double {
        guard let goal, goal.totalMinutes > 0 else { return 0 }
        let worked = (0..<goal.days).reduce(0) { $0 + min(loggedMinutes(on: goal.date(ofDay: $1)), goal.dailyMinutes[$1]) }
        return Double(worked) / Double(goal.totalMinutes)
    }
}

enum TaskSort: String, CaseIterable, Codable {
    case custom, name, progress

    var title: String { rawValue.capitalized }
}

enum TaskGrouping: String, CaseIterable, Codable {
    case none, goal

    var title: String { self == .none ? "None" : "Hours goal" }
}

/// Lists and tasks, saved as JSON in ~/Library/Application Support/Tick/tasks.json.
@Observable
final class TaskStore {
    private(set) var lists: [TaskList] = []
    private(set) var tasks: [TaskItem] = []
    var selectedListID: UUID? { didSet { save() } }
    var sort: TaskSort = .custom { didSet { save() } }
    var grouping: TaskGrouping = .none { didSet { save() } }

    @ObservationIgnored private let url: URL?
    @ObservationIgnored private var loading = false

    private struct Saved: Codable {
        var lists: [TaskList]
        var tasks: [TaskItem]
        var selectedListID: UUID?
        var sort: TaskSort
        var grouping: TaskGrouping
    }

    init(inMemory: Bool = false) {
        if inMemory {
            url = nil
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tick", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("tasks.json")
        }
        loading = true
        if let url, let data = try? Data(contentsOf: url) {
            if let saved = try? JSONDecoder().decode(Saved.self, from: data) {
                lists = saved.lists
                tasks = saved.tasks
                selectedListID = saved.selectedListID
                sort = saved.sort
                grouping = saved.grouping
            } else {
                setAsideUnreadable(url)
            }
        }
        if lists.isEmpty { lists = [TaskList(name: "Study")] }
        if selectedListID == nil || !lists.contains(where: { $0.id == selectedListID }) { selectedListID = lists[0].id }
        loading = false
    }

    var selectedList: TaskList? { lists.first { $0.id == selectedListID } }

    func task(_ id: UUID?) -> TaskItem? { tasks.first { $0.id == id } }

    /// Open tasks across all lists, for the Timer's "Working on" picker.
    var openTasks: [TaskItem] { tasks.filter { !$0.isDone }.sorted { $0.order < $1.order } }

    /// Tasks in the selected list, sorted. Completed tasks always sink to the bottom.
    var visibleTasks: [TaskItem] {
        let inList = tasks.filter { $0.listID == selectedListID }
        let sorted: [TaskItem] = switch sort {
        case .custom: inList.sorted { $0.order < $1.order }
        case .name: inList.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress: inList.sorted { $0.goalProgress > $1.goalProgress }
        }
        return sorted.filter { !$0.isDone } + sorted.filter(\.isDone)
    }

    // MARK: Lists

    func addList(named name: String) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let list = TaskList(name: name)
        lists.append(list)
        selectedListID = list.id
        save()
    }

    func deleteList(_ id: UUID) {
        guard lists.count > 1 else { return }
        lists.removeAll { $0.id == id }
        tasks.removeAll { $0.listID == id }
        if selectedListID == id { selectedListID = lists.first?.id }
        save()
    }

    // MARK: Tasks

    @discardableResult
    func addTask(_ title: String) -> TaskItem? {
        let title = title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let listID = selectedListID else { return nil }
        let task = TaskItem(listID: listID, title: title, order: (tasks.map(\.order).max() ?? 0) + 1)
        tasks.append(task)
        save()
        return task
    }

    func update(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[i])
        save()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    /// Swaps a task with its neighbour in the custom order.
    func move(_ id: UUID, up: Bool) {
        let ordered = tasks.filter { $0.listID == selectedListID }.sorted { $0.order < $1.order }
        guard let i = ordered.firstIndex(where: { $0.id == id }) else { return }
        let j = up ? i - 1 : i + 1
        guard ordered.indices.contains(j),
              let a = tasks.firstIndex(where: { $0.id == ordered[i].id }),
              let b = tasks.firstIndex(where: { $0.id == ordered[j].id }) else { return }
        (tasks[a].order, tasks[b].order) = (tasks[b].order, tasks[a].order)
        save()
    }

    /// Adds finished focus time to a task's day.
    func log(minutes: Int, to id: UUID, on date: Date = Date()) {
        update(id) { $0.logged[DayKey.of(date), default: 0] += minutes }
    }

    /// Used only by the snapshot renderer.
    func seedSample() {
        let study = lists[0]
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -11, to: Date())!
        func make(_ title: String, _ order: Int, goal: HourGoal? = nil, logged: [Int] = []) {
            var t = TaskItem(listID: study.id, title: title, order: order, goal: goal)
            for (i, m) in logged.enumerated() {
                t.logged[DayKey.of(cal.date(byAdding: .day, value: i, to: start)!)] = m
            }
            tasks.append(t)
        }
        make("Investment club", 1)
        make("ACCA Lecture", 2, goal: HourGoal(totalHours: 20, days: 10, start: cal.date(byAdding: .day, value: -3, to: Date())!),
             logged: [0, 0, 0, 0, 0, 0, 0, 0, 120, 60, 130, 45])
        make("ACCA Practice", 3, goal: HourGoal(totalHours: 28, days: 14, start: start),
             logged: [120, 72, 150, 120, 30, 126, 0, 120, 108, 132, 120, 84])
        make("Equity Research", 4)
        make("FMVA", 5, goal: HourGoal(totalHours: 7, days: 7, start: cal.date(byAdding: .day, value: -2, to: Date())!),
             logged: [0, 0, 0, 0, 0, 0, 0, 0, 0, 60, 70, 45])
    }

    private func save() {
        guard !loading, let url else { return }
        let saved = Saved(lists: lists, tasks: tasks, selectedListID: selectedListID, sort: sort, grouping: grouping)
        if let data = try? JSONEncoder().encode(saved) { try? data.write(to: url, options: .atomic) }
    }
}
