import Foundation

/// The five-rung answer to "is it a day for it?", from worst to best.
public enum DayVerdict: String, Sendable, Equatable, Comparable, CaseIterable {
    case notAChance = "not_a_chance"
    case poor
    case ifYouMust = "if_you_must"
    case decent
    case dayForIt = "day_for_it"

    public var label: String {
        switch self {
        case .notAChance: return "Not a chance"
        case .poor: return "Poor"
        case .ifYouMust: return "If you must"
        case .decent: return "Decent"
        case .dayForIt: return "Day for it"
        }
    }

    /// 0 (notAChance) through 4 (dayForIt).
    public var rank: Int {
        switch self {
        case .notAChance: return 0
        case .poor: return 1
        case .ifYouMust: return 2
        case .decent: return 3
        case .dayForIt: return 4
        }
    }

    public static func < (lhs: DayVerdict, rhs: DayVerdict) -> Bool {
        lhs.rank < rhs.rank
    }
}
