import SwiftUI
import Charts

/// Performance tab: period stats, weekly/monthly line charts, insights, and a
/// recent list (FUNCTIONALITY.md §8).
struct PerformanceView: View {
    @EnvironmentObject private var tasks: TaskService
    @EnvironmentObject private var preferences: PerformancePreferencesService

    @State private var period: PerformancePeriod = .month
    @State private var customStart = Date()
    @State private var ratingTarget: Task?

    /// The selected period scopes the whole page: stats, charts, insights, and list
    /// all derive from this one filtered set.
    private var filtered: [Task] {
        PerformanceAnalytics.filteredTasks(tasks.tasks, period: period, customStart: customStart)
    }
    private var weekly: [PerformanceDataPoint] { PerformanceAnalytics.weeklySeries(filtered) }
    private var monthly: [PerformanceDataPoint] { PerformanceAnalytics.monthlySeries(filtered) }

    /// The rating thresholds drawn as reference lines on the charts.
    private var cutoffLines: [Int] {
        let c = preferences.cutoffs
        return [c.fair, c.good, c.veryGood, c.excellent]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodSelector

                    HStack {
                        statCard(title: "Tasks Completed", value: "\(filtered.count)")
                        statCard(title: "Avg. Performance", value: String(format: "%.1f", PerformanceAnalytics.average(filtered)))
                    }

                    Divider()

                    sectionHeader("Trends")
                    chartCard(title: "Past 6 Weeks Performance", data: weekly)
                    chartCard(title: "Past 6 Months Performance", data: monthly)

                    insights
                    recentList
                }
                .padding()
            }
            .navigationTitle("Performance")
            .sheet(item: $ratingTarget) { task in
                PerformanceRatingSheet(task: task) { rating, notes in
                    if let id = task.id {
                        tasks.updateTaskPerformance(id: id, performance: rating, notes: notes)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.title3.bold())
    }

    private var periodSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("This Period")
            Picker("Period", selection: $period) {
                ForEach(PerformancePeriod.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            if period == .custom {
                DatePicker("Start date", selection: $customStart, in: ...Date(), displayedComponents: .date)
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(value).font(.system(size: 32, weight: .bold)).foregroundStyle(.blue)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }

    private func chartCard(title: String, data: [PerformanceDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Chart {
                ForEach(cutoffLines, id: \.self) { threshold in
                    RuleMark(y: .value("Cutoff", Double(threshold)))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing, spacing: 0) {
                            Text(preferences.text(for: threshold))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(preferences.color(for: threshold))
                                .padding(.trailing, 6)
                        }
                }
                ForEach(data, id: \.period) { point in
                    LineMark(x: .value("Period", point.period), y: .value("Average", point.average))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Period", point.period), y: .value("Average", point.average))
                        .foregroundStyle(preferences.color(for: Int(point.average)))
                }
            }
            .chartYScale(domain: 0...100)
            // Labels only — no interior grid; keep the x/y axis lines via the
            // plot-area edges.
            .chartXAxis { AxisMarks { AxisValueLabel() } }
            .chartYAxis { AxisMarks(position: .leading) { AxisValueLabel() } }
            .chartPlotStyle { plotArea in
                plotArea
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color(.separator)).frame(width: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
            }
            .frame(height: 180)
        }
        .padding()
        .cardStyle()
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Insights").font(.headline)
            HStack {
                insightItem("Best Week", PerformanceAnalytics.best(weekly)?.period ?? "N/A")
                insightItem("Best Month", PerformanceAnalytics.best(monthly)?.period ?? "N/A")
            }
            HStack {
                insightItem("Overall Trend", PerformanceAnalytics.overallTrend(weekly))
                insightItem("Best Rating", filtered.map(\.performanceRating).max().map { "\($0)" } ?? "N/A")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func insightItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Recent Performance")

            if filtered.isEmpty {
                Text("No completed tasks in the selected time period. Complete some tasks to see your performance data!")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(filtered.prefix(10)) { task in
                    recentRow(task)
                        .contextMenu {
                            Button { ratingTarget = task } label: { Label("Edit Rating", systemImage: "star") }
                        }
                }
            }
        }
    }

    private func recentRow(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title).font(.subheadline.bold())
                Spacer()
                Text(preferences.text(for: task.performanceRating))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(preferences.color(for: task.performanceRating), in: Capsule())
                    .foregroundStyle(.white)
            }
            HStack {
                Text("Completed: \(task.completedAt.map { DateTimeUtilities.shortDate($0) } ?? "—")")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Rating: \(task.performanceRating)/100").font(.caption2).foregroundStyle(.blue)
            }
            if let notes = task.performanceNotes, !notes.isEmpty {
                Text("Notes: \(notes)").font(.caption2).italic().foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
