import SwiftUI

/// App color palette and shared surface styling. Replaces the old hex-string
/// parsing: performance colors are `Color` constants (saturated fills that read
/// well with white text in both light and dark mode), and surfaces use adaptive
/// system colors so the UI is correct in dark mode.
extension PerformanceLevel {
    /// Fill color for this level; pairs with white text.
    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.18, green: 0.49, blue: 0.20) // green 800
        case .veryGood:  return Color(red: 0.30, green: 0.69, blue: 0.31) // green 500
        case .good:      return Color(red: 0.13, green: 0.59, blue: 0.95) // blue 500
        case .fair:      return Color(red: 1.00, green: 0.60, blue: 0.00) // orange 500
        case .poor:      return Color(red: 0.96, green: 0.26, blue: 0.21) // red 500
        }
    }
}

extension PerformancePreferencesService {
    /// Fill color for a rating, classified against the current cutoffs.
    func color(for rating: Int) -> Color { level(for: rating).color }
}

extension View {
    /// The standard rounded, bordered "card" surface used across the app.
    /// Uses adaptive system colors, so it renders correctly in dark mode.
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color(.separator)))
    }
}
