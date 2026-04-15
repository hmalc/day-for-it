import Foundation

public struct BoatDayScoreResult: Sendable, Equatable {
    public var score: Double
    public var rating: BoatDayRating
    public var reasons: [String]
}

public enum BoatDayScorer {
    public static func score(
        windKmh: Double?,
        tideSuitability: Double?,
        rainProbability: Double?,
        hasStrongWarning: Bool
    ) -> BoatDayScoreResult {
        var score = 70.0
        var reasons: [String] = []

        if let wind = windKmh {
            switch wind {
            case ..<15: score += 20; reasons.append("Light winds")
            case ..<28: score += 8; reasons.append("Manageable winds")
            case ..<40: score -= 10; reasons.append("Breezy conditions")
            case ..<55: score -= 25; reasons.append("Strong winds")
            default: score -= 40; reasons.append("Very strong winds")
            }
        } else {
            reasons.append("Wind signal limited")
        }

        if let tide = tideSuitability {
            if tide >= 0.7 {
                score += 14
                reasons.append("Favorable tide timing")
            } else if tide >= 0.4 {
                reasons.append("Neutral tide window")
            } else {
                score -= 14
                reasons.append("Unfavorable tide timing")
            }
        } else {
            reasons.append("Tide signal unavailable")
        }

        if let rain = rainProbability {
            if rain >= 0.7 {
                score -= 18
                reasons.append("High rain chance")
            } else if rain >= 0.35 {
                score -= 8
                reasons.append("Possible rain")
            }
        }

        if hasStrongWarning {
            score = min(score, 30)
            reasons.append("Marine warning active")
        }

        score = max(0, min(100, score))
        let rating: BoatDayRating
        if score >= 68 {
            rating = .green
        } else if score >= 45 {
            rating = .amber
        } else {
            rating = .red
        }
        return BoatDayScoreResult(score: score, rating: rating, reasons: Array(reasons.prefix(3)))
    }
}
