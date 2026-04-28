import Foundation

public struct BoatDayScoreResult: Sendable, Equatable {
    public var score: Double
    public var rating: BoatDayRating
    public var reasons: [String]
}

public enum BoatDayScorer {
    public static func score(
        windKmh: Double?,
        windGustKmh: Double? = nil,
        tideSuitability: Double?,
        rainProbability: Double?,
        hasStrongWarning: Bool,
        waveHeightM: Double? = nil,
        swellHeightM: Double? = nil,
        wavePeriodS: Double? = nil
    ) -> BoatDayScoreResult {
        var reasons: [String] = []
        let effectiveWind = effectiveWindKmh(sustained: windKmh, gust: windGustKmh)
        let seaRoughness = seaRoughnessMetres(waveHeightM: waveHeightM, swellHeightM: swellHeightM, periodS: wavePeriodS)

        let windScore: Double
        if let wind = effectiveWind {
            switch wind {
            case ...8:
                windScore = 100
                reasons.append("Light winds")
            case ..<15:
                windScore = 96
                reasons.append("Gentle winds")
            case ..<25:
                windScore = 88
                reasons.append("Moderate winds")
            case ..<35:
                windScore = 74
                reasons.append("Breezy conditions")
            case ..<45:
                windScore = 56
                reasons.append("Fresh winds")
            case ..<60:
                windScore = 32
                reasons.append("Strong-wind territory")
            default:
                windScore = 12
                reasons.append("Very strong winds")
            }
        } else {
            windScore = 64
        }

        let seaScore: Double
        if let roughness = seaRoughness {
            switch roughness {
            case ..<0.25:
                seaScore = 100
                reasons.append("Glassy seas")
            case ..<0.5:
                seaScore = 94
                reasons.append("Calm seas")
            case ..<0.8:
                seaScore = 84
                reasons.append("Gentle seas")
            case ..<1.1:
                seaScore = 72
                reasons.append("Manageable seas")
            case ..<1.4:
                seaScore = 62
                reasons.append("Choppy seas")
            case ..<1.7:
                seaScore = 45
                reasons.append("Lumpy seas")
            case ..<2.2:
                seaScore = 28
                reasons.append("Rough seas")
            default:
                seaScore = 8
                reasons.append("Very rough seas")
            }
        } else {
            seaScore = 64
            reasons.append("Sea state not quantified")
        }

        let tideScore: Double
        if let tide = tideSuitability {
            if tide >= 0.85 {
                tideScore = 100
                reasons.append("Great tide window")
            } else if tide >= 0.65 {
                tideScore = 88
                reasons.append("Favourable tide timing")
            } else if tide >= 0.4 {
                tideScore = 70
                reasons.append("Neutral tide window")
            } else {
                tideScore = 48
                reasons.append("Awkward tide timing")
            }
        } else {
            tideScore = 62
        }

        let rainScore: Double
        if let rain = rainProbability {
            if rain <= 0.05 {
                rainScore = 100
            } else if rain < 0.35 {
                rainScore = 92
            } else if rain < 0.7 {
                rainScore = 70
                reasons.append("Possible rain")
            } else {
                rainScore = 42
                reasons.append("High rain chance")
            }
        } else {
            rainScore = 78
        }

        var score = seaScore * 0.62 + windScore * 0.22 + tideScore * 0.08 + rainScore * 0.08
        score = min(score, seaStateCap(seaRoughness))

        if let wind = effectiveWind {
            if wind >= 60 {
                score = min(score, 24)
            } else if wind >= 50 {
                score = min(score, 35)
            } else if wind >= 42 {
                score = min(score, 48)
            } else if wind >= 35 {
                score = min(score, 62)
            }
        }

        if let gust = windGustKmh {
            if gust >= 65 {
                score = min(score, 28)
            } else if gust >= 55 {
                score = min(score, 40)
            }
        }

        if let rain = rainProbability {
            if rain >= 0.8 {
                score = min(score, 55)
            } else if rain >= 0.65 {
                score = min(score, 68)
            }
        }

        if hasStrongWarning {
            score = min(score, 30)
            reasons.append("Marine warning active")
        }

        score = max(0, min(100, score))
        let rating: BoatDayRating
        if score >= 75 {
            rating = .green
        } else if score >= 50 {
            rating = .amber
        } else {
            rating = .red
        }
        return BoatDayScoreResult(score: score, rating: rating, reasons: reasons)
    }

    private static func effectiveWindKmh(sustained: Double?, gust: Double?) -> Double? {
        let gustEquivalent = gust.map { $0 * 0.75 }
        switch (sustained, gustEquivalent) {
        case let (sustained?, gustEquivalent?):
            return max(sustained, gustEquivalent)
        case let (sustained?, nil):
            return sustained
        case let (nil, gustEquivalent?):
            return gustEquivalent
        case (nil, nil):
            return nil
        }
    }

    private static func seaRoughnessMetres(waveHeightM: Double?, swellHeightM: Double?, periodS: Double?) -> Double? {
        let candidates = [
            waveHeightM,
            swellHeightM.map { $0 * 0.9 },
        ].compactMap { $0 }
        guard let base = candidates.max() else { return nil }
        guard let periodS, periodS > 0, periodS < 8, base >= 0.8 else { return base }
        return base + 0.2
    }

    private static func seaStateCap(_ roughness: Double?) -> Double {
        guard let roughness else { return 72 }
        switch roughness {
        case ..<0.4:
            return 100
        case ..<0.7:
            return 96
        case ..<1.0:
            return 88
        case ..<1.2:
            return 78
        case ..<1.5:
            return 68
        case ..<1.8:
            return 55
        case ..<2.2:
            return 40
        case ..<2.6:
            return 30
        default:
            return 18
        }
    }
}
