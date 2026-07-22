import SwiftUI

/// Settings tab: Personal Preferences navigation + database management
/// (FUNCTIONALITY.md §9).
struct SettingsView: View {
    let database: SwiftDataDatabase

    @State private var alert: SettingsAlert?

    private struct SettingsAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Personal Preferences") {
                    NavigationLink("Performance & Preferences") {
                        PersonalPreferencesView()
                    }
                }

                #if DEBUG
                // Database management is a developer-only aid; excluded from
                // release builds (FUNCTIONALITY.md §9).
                Section("Database Management") {
                    Button("Database Test") {
                        let ok = !database.stats().isClosed
                        alert = SettingsAlert(title: "Database Test",
                                              message: ok ? "Database connection test passed!" : "Database connection test failed!")
                    }
                    Button("Database Stats") {
                        let s = database.stats()
                        alert = SettingsAlert(title: "Database Stats",
                                              message: "Tasks: \(s.taskCount)\nSubtasks: \(s.subTaskCount)\nEvents: \(s.eventCount)\nSchema: v\(s.schemaVersion)")
                    }
                    Button("Erase All Data", role: .destructive) {
                        try? database.reset()
                        alert = SettingsAlert(title: "Success", message: "All data has been cleared successfully.")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .alert(item: $alert) { a in
                Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
            }
        }
    }
}

/// Personal Preferences → link to Performance Cutoffs (FUNCTIONALITY.md §9).
struct PersonalPreferencesView: View {
    var body: some View {
        List {
            Section("Performance Settings") {
                NavigationLink {
                    PerformanceCutoffsView()
                } label: {
                    VStack(alignment: .leading) {
                        Text("Performance Cutoffs")
                        Text("Customize rating thresholds").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Personal Preferences")
    }
}

/// Edit the performance-rating cutoffs (FUNCTIONALITY.md §9).
struct PerformanceCutoffsView: View {
    @EnvironmentObject private var preferences: PerformancePreferencesService

    @State private var fair = 0
    @State private var good = 0
    @State private var veryGood = 0
    @State private var excellent = 0
    @State private var savedAlert = false

    var body: some View {
        Form {
            Section {
                Text("Customize the rating thresholds for performance evaluation. Anything below the \"Fair\" threshold is considered \"Poor\".")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                cutoffRow("Fair", value: $fair)
                cutoffRow("Good", value: $good)
                cutoffRow("Very Good", value: $veryGood)
                cutoffRow("Excellent", value: $excellent)
            }
            Section {
                Button("Save Changes") { save() }
                Button("Reset to Defaults", role: .destructive) {
                    preferences.resetToDefaults()
                    seed()
                }
            }
        }
        .navigationTitle("Performance Cutoffs")
        .onAppear(perform: seed)
        .alert("Success", isPresented: $savedAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text("Performance cutoffs saved successfully!") }
    }

    private func cutoffRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func seed() {
        let c = preferences.cutoffs
        fair = c.fair; good = c.good
        veryGood = c.veryGood; excellent = c.excellent
    }

    private func save() {
        preferences.setCutoffs(PerformanceCutoffs(
            fair: fair, good: good, veryGood: veryGood, excellent: excellent
        ))
        seed()
        savedAlert = true
    }
}
