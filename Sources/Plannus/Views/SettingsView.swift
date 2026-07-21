import SwiftUI

/// Placeholder — the original `SettingsScreen` renders nothing
/// (FUNCTIONALITY.md §8).
struct SettingsView: View {
    var body: some View {
        ContentUnavailableViewCompat(
            title: "Settings",
            systemImage: "gearshape",
            description: "Coming soon."
        )
    }
}

/// A small "empty state" view that works on iOS 16 (`ContentUnavailableView`
/// requires iOS 17).
struct ContentUnavailableViewCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(description).foregroundStyle(.secondary)
        }
    }
}

#Preview { SettingsView() }
