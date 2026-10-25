import Charts
import SwiftUI

struct StatsTab: View {
    @Environment(StatsStore.self) private var stats
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        PanelScroll { content }
    }

    private var content: some View {
        let p = Palette.of(scheme)
        let today = stats.today
        let goal = max(settings.dailyGoal, 1)
        let streak = stats.streak(goal: goal)
        let week = stats.lastDays(7)
        let month = stats.lastDays(30)
        let labels = Array(stats.labelTotals(days: 7).prefix(4))

        return VStack(alignment: .leading, spacing: 8) {
            TabTitle(text: "Stats")

            HStack(alignment: .firstTextBaseline) {
                heading("Today", detail: "\(today.pomodoros) of \(goal) pomodoros")
                Spacer()
                if streak > 0 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(p.accent)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.track)
                    Capsule().fill(today.pomodoros >= goal ? p.done : p.accent)
                        .frame(width: geo.size.width * min(Double(today.pomodoros) / Double(goal), 1))
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                card("Focus", duration(today.focusSeconds), fill: p.accent,
                     label: p.onAccent.opacity(0.8), value: p.onAccent)
                card("Break", duration(today.breakSeconds), fill: p.track, label: p.muted, value: p.text)
            }
            .padding(.top, 2)

            heading("Last week", detail: "\(duration(average(week))) focus per day avg")
                .padding(.top, 6)
            Chart(week, id: \.date) { day in
                BarMark(x: .value("Day", day.date, unit: .day),
                        y: .value("Hours", Double(day.stat.focusSeconds) / 3600))
                    .foregroundStyle(Calendar.current.isDateInToday(day.date) ? p.accent : p.accent.opacity(0.65))
                    .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(p.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(p.border)
                    AxisValueLabel { if let h = value.as(Double.self) { Text("\(Int(h))h") } }
                        .foregroundStyle(p.muted)
                }
            }
            .frame(height: 110)

            if !labels.isEmpty {
                heading("This week by label", detail: "")
                    .padding(.top, 6)
                let top = Double(labels[0].seconds)
                ForEach(labels, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Spacer()
                            Text(duration(item.seconds)).font(.system(size: 11)).foregroundStyle(p.muted)
                        }
                        GeometryReader { geo in
                            Capsule().fill(p.accent.opacity(0.8))
                                .frame(width: max(6, geo.size.width * Double(item.seconds) / top))
                        }
                        .frame(height: 6)
                    }
                }
            }

            heading("Last month", detail: "\(duration(average(month))) avg")
                .padding(.top, 6)
            Chart(month, id: \.date) { day in
                BarMark(x: .value("Day", day.date, unit: .day),
                        y: .value("Hours", Double(day.stat.focusSeconds) / 3600))
                    .foregroundStyle(p.accent)
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 56)
        }
        .foregroundStyle(p.text)
    }

    private func heading(_ title: String, detail: String) -> some View {
        let p = Palette.of(scheme)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(p.muted)
        }
    }

    private func card(_ title: String, _ value: String, fill: Color, label: Color, value valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundStyle(label)
            Text(value).font(.system(size: 18, weight: .semibold)).foregroundStyle(valueColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 12))
    }

    private func average(_ days: [(date: Date, stat: DayStat)]) -> Int {
        days.map(\.stat.focusSeconds).reduce(0, +) / max(days.count, 1)
    }

    private func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds % 3600 / 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : "\(m)m"
    }
}
