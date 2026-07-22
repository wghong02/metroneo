import SwiftUI

/// Settings tab: Personal Preferences navigation + database management
/// (FUNCTIONALITY.md §9).
struct SettingsView: View {
    let database: TaskDatabase

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

    @State private var fair = ""
    @State private var good = ""
    @State private var veryGood = ""
    @State private var excellent = ""
    @State private var savedAlert = false

    var body: some View {
        Form {
            Section {
                Text("Customize the rating thresholds for performance evaluation. Anything below the \"Fair\" threshold is considered \"Poor\".")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                cutoffRow("Fair", text: $fair)
                cutoffRow("Good", text: $good)
                cutoffRow("Very Good", text: $veryGood)
                cutoffRow("Excellent", text: $excellent)
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

    private func cutoffRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func seed() {
        let c = preferences.cutoffs
        fair = String(c.fair); good = String(c.good)
        veryGood = String(c.veryGood); excellent = String(c.excellent)
    }

    private func save() {
        let d = PerformanceCutoffs.defaults
        let new = PerformanceCutoffs(
            fair: Int(fair) ?? d.fair,
            good: Int(good) ?? d.good,
            veryGood: Int(veryGood) ?? d.veryGood,
            excellent: Int(excellent) ?? d.excellent
        )
        preferences.setCutoffs(new)
        seed()
        savedAlert = true
    }
}
