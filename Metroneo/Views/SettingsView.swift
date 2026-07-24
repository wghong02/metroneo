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

    /// "<marketing version> (<build>)", e.g. "1.0 (1)" — read from the synthesized
    /// Info.plist (`CFBundleShortVersionString` / `CFBundleVersion`).
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
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

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Self.appVersion).foregroundStyle(.secondary)
                    }
                }
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
    @State private var cutoffAlert: CutoffAlert?

    private struct CutoffAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

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
        .alert(item: $cutoffAlert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
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
        guard [fair, good, veryGood, excellent].allSatisfy({ (0...100).contains($0) }) else {
            cutoffAlert = CutoffAlert(title: "Invalid Cutoffs",
                                      message: "Each threshold must be between 0 and 100.")
            return
        }
        // Levels cascade highest-first, so out-of-order thresholds silently
        // mis-classify ratings. Require them to be non-decreasing.
        guard fair <= good, good <= veryGood, veryGood <= excellent else {
            cutoffAlert = CutoffAlert(title: "Invalid Cutoffs",
                                      message: "Thresholds must not decrease: Fair ≤ Good ≤ Very Good ≤ Excellent.")
            return
        }
        preferences.setCutoffs(PerformanceCutoffs(
            fair: fair, good: good, veryGood: veryGood, excellent: excellent
        ))
        seed()
        cutoffAlert = CutoffAlert(title: "Success", message: "Performance cutoffs saved successfully!")
    }
}
