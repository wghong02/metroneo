import SwiftUI
import Charts

/// Performance tab: period stats, one adaptive trend chart, insights, and a
/// recent list (FUNCTIONALITY.md §8).
struct PerformanceView: View {
    @EnvironmentObject private var tasks: TaskService
    @EnvironmentObject private var preferences: PerformancePreferencesService

    @State private var period: PerformancePeriod = .month
    @State private var customStart = Date()
    @State private var ratingTarget: Task?
    @State private var selectedPeriod: String?

    /// The selected period scopes the whole page: stats, charts, insights, and list
    /// all derive from this one filtered set.
    private var filtered: [Task] {
        PerformanceAnalytics.filteredTasks(tasks.tasks, period: period, customStart: customStart)
    }
    /// The period's completed tasks, most-recently-completed first — the order the
    /// "Recent Performance" list needs (`filtered` is in createDate order).
    private var recentByCompletion: [Task] {
        filtered.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    /// One adaptive trend series whose bucket size follows the selected period.
    private var trend: [PerformanceDataPoint] {
        PerformanceAnalytics.trendSeries(tasks.tasks, period: period,
                                         cutoffs: preferences.cutoffs, customStart: customStart)
    }
    private var granularity: PerformanceGranularity {
        PerformanceAnalytics.granularity(for: period, tasks: tasks.tasks, customStart: customStart)
    }
    /// Rotate x labels vertical (with extra spacing) once the axis gets crowded.
    private var verticalXLabels: Bool { trend.count > 8 }

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
                    trendCard

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
            sectionHeader("Period")
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

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(granularity.label) Performance")
                .font(.headline)
                .padding(.bottom, 6)

            performanceChart

            Text("Tasks Completed")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 6)
            distributionChart

            distributionLegend
        }
        .padding()
        .cardStyle()
    }

    /// Top plot: average performance line (0–100) with cutoff reference lines.
    private var performanceChart: some View {
        Chart {
            ForEach(cutoffLines, id: \.self) { threshold in
                RuleMark(y: .value("Cutoff", Double(threshold)))
                    .foregroundStyle(preferences.color(for: threshold).opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 3]))
            }
            // Only plot buckets that actually have completed tasks; empty buckets
            // stay a gap on the line instead of dropping to a misleading 0.
            ForEach(trend.filter { $0.taskCount > 0 }, id: \.period) { point in
                LineMark(x: .value("Period", point.period), y: .value("Average", point.average))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Period", point.period), y: .value("Average", point.average))
                    .symbolSize(25)
                    .foregroundStyle(preferences.color(for: Int(point.average)))
            }
            if let selectedPeriod, let point = trend.first(where: { $0.period == selectedPeriod }) {
                RuleMark(x: .value("Period", selectedPeriod))
                    .foregroundStyle(.gray.opacity(0.4))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        selectionCallout(point)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: trend.map(\.period))
        .chartXSelection(value: $selectedPeriod)
        .chartXAxis {
            AxisMarks {
                AxisValueLabel(
                    orientation: verticalXLabels ? .vertical : .automatic,
                    verticalSpacing: verticalXLabels ? 8 : nil
                )
            }
        }
        .chartYAxis { AxisMarks(position: .leading) { yLabel($0.as(Double.self).map { Int($0) }) } }
        .chartPlotStyle { edgedPlot($0) }
        .frame(height: 170)
    }

    /// Bottom plot: task count per bucket, stacked by performance category.
    private var distributionChart: some View {
        Chart {
            ForEach(trend, id: \.period) { point in
                ForEach(point.levelCounts, id: \.level) { lc in
                    if lc.count > 0 {
                        BarMark(x: .value("Period", point.period), y: .value("Count", lc.count))
                            .foregroundStyle(lc.level.color)
                    }
                }
            }
        }
        .chartXScale(domain: trend.map(\.period))
        .chartXAxis {
            AxisMarks {
                AxisValueLabel(
                    orientation: verticalXLabels ? .vertical : .automatic,
                    verticalSpacing: verticalXLabels ? 8 : nil
                )
            }
        }
        .chartYAxis { AxisMarks(position: .leading) { yLabel($0.as(Int.self)) } }
        .chartPlotStyle { edgedPlot($0) }
        .frame(height: 110)
    }

    /// Fixed-width y-axis label so the two stacked charts' plots line up.
    private func yLabel(_ value: Int?) -> some AxisMark {
        AxisValueLabel {
            if let value {
                Text("\(value)").frame(width: 24, alignment: .trailing)
            }
        }
    }

    /// Left + bottom axis lines, no interior grid.
    private func edgedPlot(_ plotArea: some View) -> some View {
        plotArea
            .overlay(alignment: .leading) { Rectangle().fill(Color(.separator)).frame(width: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color(.separator)).frame(height: 1) }
    }

    /// Category color key shown under the chart (bars + cutoff lines).
    private var distributionLegend: some View {
        HStack(spacing: 10) {
            ForEach(PerformanceLevel.allCases, id: \.self) { level in
                HStack(spacing: 4) {
                    Circle().fill(level.color).frame(width: 8, height: 8)
                    Text(level.rawValue).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .minimumScaleFactor(0.7)
    }

    /// Tap-to-inspect callout for a selected trend point.
    private func selectionCallout(_ point: PerformanceDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.period).font(.caption2.bold())
            Text("Avg \(String(format: "%.0f", point.average))")
                .font(.caption2)
                .foregroundStyle(preferences.color(for: Int(point.average)))
            Text("\(point.taskCount) task\(point.taskCount == 1 ? "" : "s")")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Insights").font(.headline)
            HStack {
                insightItem("Best Period", PerformanceAnalytics.best(trend)?.period ?? "N/A")
                insightItem("Overall Trend", PerformanceAnalytics.overallTrend(trend))
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
                ForEach(recentByCompletion.prefix(10)) { task in
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
