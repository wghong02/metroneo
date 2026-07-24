import XCTest
@testable import Metroneo

final class PerformancePreferencesServiceTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testDefaultsWhenNothingStored() {
        let svc = PerformancePreferencesService(defaults: makeDefaults())
        XCTAssertEqual(svc.cutoffs, .defaults)
    }

    func testSetCutoffsPersistsAcrossInstances() {
        let defaults = makeDefaults()
        let custom = PerformanceCutoffs(fair: 50, good: 65, veryGood: 80, excellent: 95)
        PerformancePreferencesService(defaults: defaults).setCutoffs(custom)
        // A new service reading the same store loads the saved cutoffs.
        XCTAssertEqual(PerformancePreferencesService(defaults: defaults).cutoffs, custom)
    }

    func testResetToDefaults() {
        let defaults = makeDefaults()
        let svc = PerformancePreferencesService(defaults: defaults)
        svc.setCutoffs(PerformanceCutoffs(fair: 10, good: 20, veryGood: 30, excellent: 40))
        svc.resetToDefaults()
        XCTAssertEqual(svc.cutoffs, .defaults)
        XCTAssertEqual(PerformancePreferencesService(defaults: defaults).cutoffs, .defaults)
    }

    func testLevelAndTextUseCurrentCutoffs() {
        let svc = PerformancePreferencesService(defaults: makeDefaults())
        svc.setCutoffs(PerformanceCutoffs(fair: 40, good: 60, veryGood: 80, excellent: 90))
        XCTAssertEqual(svc.level(for: 85), .veryGood)
        XCTAssertEqual(svc.text(for: 85), "Very Good")
        XCTAssertEqual(svc.level(for: 30), .poor)
    }
}
