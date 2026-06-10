import Foundation

/// Warning tiers as classified from BOM marine warning titles.
public enum MarineWarningClass: Sendable, Equatable {
    case advisory
    case strong
    case severe
}

public struct DayVerdictResult: Sendable, Equatable {
    public var verdict: DayVerdict
    /// The factor that set the verdict (worst factor wins).
    public var limitedBy: String
    /// All factor statements, worst first.
    public var reasons: [String]

    public init(verdict: DayVerdict, limitedBy: String, reasons: [String]) {
        self.verdict = verdict
        self.limitedBy = limitedBy
        self.reasons = reasons
    }
}

/// Worst-factor-wins verdict for a boating day.
///
/// Each factor with real data votes a rung; the day gets the lowest vote.
/// "Day for it" requires positive evidence of both light wind and low seas —
/// a factor without data caps the day at "Decent" rather than guessing.
/// With no wind and no sea data at all there is no verdict.
public enum DayVerdictScorer {
    public static func verdict(
        windKmh: Double?,
        windGustKmh: Double? = nil,
        seasM: Double? = nil,
        warning: MarineWarningClass? = nil,
        severeWeatherMention: String? = nil
    ) -> DayVerdictResult? {
        let effectiveWind = effectiveWindKmh(sustained: windKmh, gust: windGustKmh)
        guard effectiveWind != nil || seasM != nil else { return nil }

        var votes: [(DayVerdict, String)] = []

        if let wind = effectiveWind {
            votes.append(windVote(wind))
        } else {
            votes.append((.decent, "Wind not quantified"))
        }

        if let seas = seasM {
            votes.append(seaVote(seas))
        } else {
            votes.append((.decent, "Sea state not quantified"))
        }

        if let warning {
            switch warning {
            case .severe:
                votes.append((.notAChance, "Gale or storm-tier marine warning active"))
            case .strong:
                votes.append((.poor, "Strong wind warning active"))
            case .advisory:
                votes.append((.decent, "Marine advisory active"))
            }
        }

        if let severeWeatherMention {
            votes.append((.ifYouMust, "Forecast mentions \(severeWeatherMention)"))
        }

        let ordered = votes.sorted { $0.0 < $1.0 }
        let worst = ordered[0]
        return DayVerdictResult(
            verdict: worst.0,
            limitedBy: worst.1,
            reasons: ordered.map(\.1)
        )
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

    private static func windVote(_ kmh: Double) -> (DayVerdict, String) {
        let value = "(~\(Int(kmh.rounded())) km/h)"
        switch kmh {
        case ...15: return (.dayForIt, "Light winds \(value)")
        case ...22: return (.decent, "Gentle winds \(value)")
        case ...31: return (.ifYouMust, "Moderate winds \(value)")
        case ...46: return (.poor, "Fresh winds \(value)")
        default: return (.notAChance, "Strong winds \(value)")
        }
    }

    private static func seaVote(_ metres: Double) -> (DayVerdict, String) {
        let value = String(format: "(%.1f m)", metres)
        switch metres {
        case ...0.5: return (.dayForIt, "Glassy seas \(value)")
        case ...1.0: return (.decent, "Low seas \(value)")
        case ...1.5: return (.ifYouMust, "Choppy seas \(value)")
        case ...2.2: return (.poor, "Rough seas \(value)")
        default: return (.notAChance, "Very rough seas \(value)")
        }
    }
}
