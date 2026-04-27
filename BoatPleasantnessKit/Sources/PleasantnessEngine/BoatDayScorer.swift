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
        hasStrongWarning: Bool,
        waveHeightM: Double? = nil
    ) -> BoatDayScoreResult {
        var reasons: [String] = []

        let windScore: Double
        if let wind = windKmh {
            switch wind {
            case ..<15:
                windScore = 96
                reasons.append("Light winds")
            case ..<28:
                windScore = 86
                reasons.append("Manageable winds")
            case ..<38:
                windScore = 68
                reasons.append("Breezy conditions")
            case ..<48:
                windScore = 48
                reasons.append("Fresh winds")
            case ..<63:
                windScore = 24
                reasons.append("Strong-wind territory")
            default:
                windScore = 10
                reasons.append("Very strong winds")
            }
        } else {
            windScore = 58
            reasons.append("Wind detail pending")
        }

        let seaScore: Double
        if let waves = waveHeightM {
            switch waves {
            case ..<0.6:
                seaScore = 96
                reasons.append("Low seas")
            case ..<1.0:
                seaScore = 84
                reasons.append("Modest seas")
            case ..<1.5:
                seaScore = 62
                reasons.append("Lumpy seas")
            case ..<2.5:
                seaScore = 32
                reasons.append("Rough seas")
            default:
                seaScore = 12
                reasons.append("Very rough seas")
            }
        } else {
            seaScore = 58
            reasons.append("Sea state detail pending")
        }

        let tideScore: Double
        if let tide = tideSuitability {
            if tide >= 0.7 {
                tideScore = 90
                reasons.append("Favorable tide timing")
            } else if tide >= 0.4 {
                tideScore = 70
                reasons.append("Neutral tide window")
            } else {
                tideScore = 48
                reasons.append("Awkward tide timing")
            }
        } else {
            tideScore = 62
            reasons.append("Tide timing pending")
        }

        let rainScore: Double
        if let rain = rainProbability {
            if rain >= 0.7 {
                rainScore = 42
                reasons.append("High rain chance")
            } else if rain >= 0.35 {
                rainScore = 70
                reasons.append("Possible rain")
            } else {
                rainScore = 92
            }
        } else {
            rainScore = 78
        }

        var score = seaScore * 0.44 + windScore * 0.36 + tideScore * 0.10 + rainScore * 0.10

        if let waves = waveHeightM {
            if waves >= 2.5 {
                score = min(score, 28)
            } else if waves >= 1.8 {
                score = min(score, 40)
            } else if waves >= 1.5 {
                score = min(score, 48)
            }
        }

        if let wind = windKmh {
            if wind >= 63 {
                score = min(score, 24)
            } else if wind >= 48 {
                score = min(score, 34)
            } else if wind >= 38 {
                score = min(score, 52)
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
