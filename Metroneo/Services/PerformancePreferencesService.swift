import Foundation
import Combine

/// Rating thresholds for performance categorization (FUNCTIONALITY.md §4.3).
public struct PerformanceCutoffs: Codable, Equatable {
    public var fair: Int
    public var good: Int
    public var veryGood: Int
    public var excellent: Int

    public init(fair: Int, good: Int, veryGood: Int, excellent: Int) {
        self.fair = fair
        self.good = good
        self.veryGood = veryGood
        self.excellent = excellent
    }

    /// Service default (note: distinct from the Cutoffs *screen's* input seed of
    /// 25/50/75/100).
    public static let defaults = PerformanceCutoffs(fair: 60, good: 75, veryGood: 80, excellent: 90)
}

/// Performance category label.
public enum PerformanceLevel: String {
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    /// Hex color for this performance level.
    public var hex: String {
        switch self {
        case .excellent: return "#2E7D32"
        case .veryGood:  return "#4CAF50"
        case .good:      return "#2196F3"
        case .fair:      return "#FF9800"
        case .poor:      return "#F44336"
        }
    }
}

/// Persists ``PerformanceCutoffs`` under `@performance_cutoffs` and classifies
/// ratings (FUNCTIONALITY.md §4.3).
public final class PerformancePreferencesService: ObservableObject {
    public static let storageKey = "@performance_cutoffs"

    @Published public private(set) var cutoffs: PerformanceCutoffs

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(PerformanceCutoffs.self, from: data) {
            self.cutoffs = stored
        } else {
            self.cutoffs = .defaults
        }
    }

    public func setCutoffs(_ new: PerformanceCutoffs) {
        cutoffs = new
        if let data = try? JSONEncoder().encode(new) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    public func resetToDefaults() { setCutoffs(.defaults) }

    /// Classifies a rating against the current cutoffs.
    public func level(for rating: Int) -> PerformanceLevel { Self.level(for: rating, cutoffs: cutoffs) }

    public static func level(for rating: Int, cutoffs: PerformanceCutoffs) -> PerformanceLevel {
        if rating >= cutoffs.excellent { return .excellent }
        if rating >= cutoffs.veryGood { return .veryGood }
        if rating >= cutoffs.good { return .good }
        if rating >= cutoffs.fair { return .fair }
        return .poor
    }

    public func text(for rating: Int) -> String { level(for: rating).rawValue }
    public func color(for rating: Int) -> String { level(for: rating).hex }
}
