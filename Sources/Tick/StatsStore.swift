import Foundation
import Observation

struct DayStat: Codable {
    var focusSeconds = 0
    var breakSeconds = 0
    var pomodoros = 0
    /// Focus seconds per session label ("Python course" → 3000).
    var labels: [String: Int] = [:]
}

extension DayStat {
    /// Tolerates files saved before newer fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focusSeconds = try c.decodeIfPresent(Int.self, forKey: .focusSeconds) ?? 0
        breakSeconds = try c.decodeIfPresent(Int.self, forKey: .breakSeconds) ?? 0
        pomodoros = try c.decodeIfPresent(Int.self, forKey: .pomodoros) ?? 0
        labels = try c.decodeIfPresent([String: Int].self, forKey: .labels) ?? [:]
    }
}

/// Per-day totals, saved as JSON in ~/Library/Application Support/Tick/stats.json.
@Observable
final class StatsStore {
    private(set) var days: [String: DayStat] = [:]
    @ObservationIgnored private let url: URL?

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(inMemory: Bool = false) {
        guard !inMemory else { url = nil; return }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tick", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("stats.json")
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: DayStat].self, from: data) {
            days = saved
        }
    }

    func day(_ date: Date) -> DayStat {
        days[Self.keyFormatter.string(from: date)] ?? DayStat()
    }

    var today: DayStat { day(Date()) }

    /// The last `count` days, oldest first, ending today.
    func lastDays(_ count: Int) -> [(date: Date, stat: DayStat)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            return (date, day(date))
        }
    }

    /// Consecutive days hitting the goal. Today only counts once it's reached, so an
    /// unfinished today doesn't break the streak.
    func streak(goal: Int) -> Int {
        let cal = Calendar.current
        var date = cal.startOfDay(for: Date())
        if day(date).pomodoros < goal { date = cal.date(byAdding: .day, value: -1, to: date)! }
        var count = 0
        while day(date).pomodoros >= goal, count < 3650 {
            count += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    /// Focus seconds per label over the last `days` days, largest first.
    func labelTotals(days count: Int) -> [(label: String, seconds: Int)] {
        var totals: [String: Int] = [:]
        for (_, stat) in lastDays(count) {
            for (label, seconds) in stat.labels { totals[label, default: 0] += seconds }
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.seconds > $1.seconds }
    }

    func recordFocus(seconds: Int, countsAsPomodoro: Bool, label: String) {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        update { stat in
            stat.focusSeconds += seconds
            if countsAsPomodoro { stat.pomodoros += 1 }
            if !label.isEmpty { stat.labels[label, default: 0] += seconds }
        }
    }

    func recordBreak(seconds: Int) {
        update { $0.breakSeconds += seconds }
    }

    /// Used only by the snapshot renderer to show realistic charts.
    func seedSample() {
        let cal = Calendar.current
        for offset in 0..<30 {
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            let poms = [5, 8, 9, 8, 4, 5, 4, 6, 1, 4][offset % 10]
            let python = min(poms, 3) * 25 * 60
            days[Self.keyFormatter.string(from: date)] = DayStat(
                focusSeconds: poms * 25 * 60, breakSeconds: poms * 5 * 60, pomodoros: poms,
                labels: ["Python course": python, "Reading": (poms - min(poms, 3)) * 25 * 60 / 2,
                         "Backtest script": (poms - min(poms, 3)) * 25 * 60 / 2])
        }
    }

    private func update(_ change: (inout DayStat) -> Void) {
        let key = Self.keyFormatter.string(from: Date())
        var stat = days[key] ?? DayStat()
        change(&stat)
        days[key] = stat
        save()
    }

    private func save() {
        guard let url, let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
