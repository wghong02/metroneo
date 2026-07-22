import SwiftUI
import Charts

/// Performance tab: period stats, weekly/monthly line charts, insights, and a
/// recent list (FUNCTIONALITY.md §8).
struct PerformanceView: View {
    @EnvironmentObject private var tasks: TaskService
    @EnvironmentObject private var preferences: PerformancePreferencesService

    @State private var period: PerformancePeriod = .week
    @State private var customStart = ""
    @State private var ratingTarget: Task?

    private var filtered: [Task] {
        PerformanceAnalytics.filteredTasks(tasks.tasks, period: period, customStart: customStart)
    }
    private var weekly: [PerformanceDataPoint] { PerformanceAnalytics.weeklySeries(tasks.tasks) }
    private var monthly: [PerformanceDataPoint] { PerformanceAnalytics.monthlySeries(tasks.tasks) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodSelector

                    HStack {
                        statCard(title: "Tasks Completed", value: "\(filtered.count)")
                        statCard(title: "Avg. Performance", value: String(format: "%.1f", PerformanceAnalytics.average(filtered)))
                    }

                    chartCard(title: "Past 5 Weeks Performance", data: weekly)
                    chartCard(title: "Past 5 Months Performance", data: monthly)

                    insights
                    recentList
                }
                .padding()
            }
            .navigationTitle("Performance")
            .refreshable {
                tasks.loadTasks()
            }
            .sheet(item: $ratingTarget) { task in
                PerformanceRatingSheet(task: task) { rating, notes in
                    if let id = task.id {
                        tasks.updateTaskPerformance(id: id, performance: rating, notes: notes)
                    }
                }
            }
        }
    }

    private var periodSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Time Period").font(.headline)
            Picker("Period", selection: $period) {
                ForEach(PerformancePeriod.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            if period == .custom {
                TextField("Start date (YYYY-MM-DD)", text: $customStart)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
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
        .background(Color(hex: "#F8F9FA"), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0E0E0")))
    }

    private func chartCard(title: String, data: [PerformanceDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Chart(data, id: \.period) { point in
                LineMark(x: .value("Period", point.period), y: .value("Average", point.average))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Period", point.period), y: .value("Average", point.average))
                    .foregroundStyle(Color(hex: preferences.color(for: Int(point.average))))
            }
            .chartYScale(domain: 0...100)
            .frame(height: 180)
        }
        .padding()
        .background(Color(hex: "#F8F9FA"), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0E0E0")))
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
                insightItem("Total Tasks", "\(tasks.tasks.filter { $0.isCompleted }.count)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F8F9FA"), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0E0E0")))
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
            Text("Recent Performance").font(.title3.bold())
            Text("Long-press a task to edit its performance rating")
                .font(.caption).italic().foregroundStyle(.secondary)

            if filtered.isEmpty {
                Text("No completed tasks in the selected time period. Complete some tasks to see your performance data!")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(filtered.prefix(10)) { task in
                    recentRow(task)
                        .onLongPressGesture { ratingTarget = task }
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
                    .background(Color(hex: preferences.color(for: task.performanceRating)), in: Capsule())
                    .foregroundStyle(.white)
            }
            HStack {
                Text("Completed: \(DateTimeUtilities.localizedDate(fromKey: task.completedAt))")
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
        .background(Color(hex: "#F8F9FA"), in: RoundedRectangle(cornerRadius: 12))
    }
}
