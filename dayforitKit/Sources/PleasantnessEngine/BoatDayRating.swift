import Foundation

public enum BoatDayRating: String, Sendable, Equatable {
    case green
    case amber
    case red

    public var label: String {
        switch self {
        case .green: return "Good"
        case .amber: return "Mixed"
        case .red: return "Poor"
        }
    }
}
