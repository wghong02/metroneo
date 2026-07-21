import SwiftUI

/// Placeholder — the original `PerformanceScreen` renders nothing
/// (FUNCTIONALITY.md §8).
struct PerformanceView: View {
    var body: some View {
        ContentUnavailableViewCompat(
            title: "Performance",
            systemImage: "chart.bar",
            description: "Coming soon."
        )
    }
}

#Preview { PerformanceView() }
