import Foundation

/// Multivariable "boat pleasantness" model: higher is calmer and more comfortable for casual ocean boating.
public enum PleasantnessEngine: Sendable {
    // MARK: - Weights (sum ≈ 1.0 for base blend before interactions)

    private static let wWind = 0.28
    private static let wSea = 0.30
    private static let wWet = 0.12
    private static let wVis = 0.12
    private static let wThermal = 0.10
    private static let wHazardText = 0.08

    public static func evaluate(_ input: ScoringInput) -> PleasantnessResult {
        let effectiveWind = effectiveWindKmh(input)
        let gustFactor = gustFactor(input, effectiveWind: effectiveWind)

        let windScore = windComfort(effectiveWind: effectiveWind, gustFactor: gustFactor)
        let seaScore = seaMotion(input: input, effectiveWind: effectiveWind)
        let wetScore = wetness(input.rainProbability)
        let visScore = visibility(input.visibilityKm, cloud: input.cloudCoverPercent)
        let thermalScore = thermalComfort(airC: input.airTemperatureC, uv: input.uvIndex)
        let hazardScore = hazardKeywordPenalty(input.hazardKeywords)

        // Interaction: short-period swell + moderate wind feels worse than long-period swell at same wind.
        let period = input.swellPeriodSeconds ?? 10
        let chopPenalty = interactionChopPenalty(
            windKmh: effectiveWind,
            seaM: input.seaHeightMetres,
            swellM: input.swellHeightMetres,
            swellPeriod: period
        )

        let windTerm = Self.wWind * windScore.value
        let seaTerm = Self.wSea * (seaScore.value * chopPenalty)
        let wetTerm = Self.wWet * wetScore.value
        let visTerm = Self.wVis * visScore.value
        let thermalTerm = Self.wThermal * thermalScore.value
        let hazardTerm = Self.wHazardText * hazardScore.value
        var combined = windTerm + seaTerm + wetTerm + visTerm + thermalTerm + hazardTerm

        combined = combined.clamped(to: 0...100)

        let (capped, limited, warnSummary) = applyWarningCap(
            base: combined,
            warnings: input.activeWarnings
        )

        let drivers = buildDrivers(
            wind: windScore,
            sea: seaScore,
            wet: wetScore,
            vis: visScore,
            thermal: thermalScore,
            hazard: hazardScore,
            chopPenalty: chopPenalty,
            gustFactor: gustFactor,
            warningLimited: limited
        )

        return PleasantnessResult(
            index: capped,
            subScores: [windScore, seaScore, wetScore, visScore, thermalScore, hazardScore],
            topDrivers: Array(drivers.prefix(3)),
            isWarningLimited: limited,
            warningSummary: warnSummary
        )
    }

    // MARK: - Wind

    private static func effectiveWindKmh(_ input: ScoringInput) -> Double {
        let candidates = [input.windSpeedKmh, input.coastalWindMaxKmh].compactMap { $0 }
        return candidates.max() ?? 0
    }

    /// Ratio of gustiness vs sustained (1 = calm match).
    private static func gustFactor(_ input: ScoringInput, effectiveWind: Double) -> Double {
        guard let g = input.windGustKmh, effectiveWind > 0.5 else { return 1.0 }
        let ratio = g / max(effectiveWind, 1)
        return ratio.clamped(to: 1.0...2.2)
    }

    private static func windComfort(effectiveWind: Double, gustFactor: Double) -> SubScore {
        // Beaufort-like comfort for small craft: pleasant under ~15 kt (~28 km/h), degrades quickly above ~40 km/h.
        let base: Double
        switch effectiveWind {
        case ..<15: base = 98
        case ..<28: base = 88
        case ..<40: base = 72
        case ..<55: base = 48
        case ..<70: base = 28
        default: base = 10
        }
        let gustAdjusted = base / gustFactor
        let v = gustAdjusted.clamped(to: 0...100)
        let detail: String
        if effectiveWind < 1 {
            detail = "No recent wind observation; assuming light conditions."
        } else {
            detail = String(format: "About %.0f km/h sustained (gust factor ×%.2f).", effectiveWind, gustFactor)
        }
        return SubScore(value: v, label: "Wind comfort", detail: detail)
    }

    // MARK: - Sea state

    private static func seaMotion(input: ScoringInput, effectiveWind: Double) -> SubScore {
        let sea = input.seaHeightMetres ?? inferredSeaFromWind(effectiveWind)
        let swell = input.swellHeightMetres ?? 0
        let rough = max(sea, swell * 0.85)

        let v: Double
        switch rough {
        case ..<0.6: v = 95
        case ..<1.0: v = 82
        case ..<1.5: v = 65
        case ..<2.5: v = 42
        default: v = 18
        }

        let detail: String
        if input.seaHeightMetres != nil || input.swellHeightMetres != nil {
            detail = String(format: "Roughness index ~%.1f m (seas/swell combined heuristically).", rough)
        } else {
            detail = "Sea state estimated from wind (no explicit seas height yet)."
        }
        return SubScore(value: v.clamped(to: 0...100), label: "Sea motion", detail: detail)
    }

    private static func inferredSeaFromWind(_ kmh: Double) -> Double {
        // Very rough proxy when only wind known (not metres-accurate; keeps model responsive).
        max(0, min(3.5, (kmh / 55) * 1.8))
    }

    /// Returns multiplier in (0,1] applied to sea comfort.
    private static func interactionChopPenalty(
        windKmh: Double,
        seaM: Double?,
        swellM: Double?,
        swellPeriod: Double
    ) -> Double {
        let sea = seaM ?? inferredSeaFromWind(windKmh)
        let swell = swellM ?? 0
        let shortPeriod = swellPeriod < 8
        let windSea = max(0, sea - swell * 0.4) // crude wind-sea component
        var penalty = 1.0
        if shortPeriod && swell > 1.0 {
            penalty -= 0.12
        }
        if windSea > 1.0 && windKmh > 35 {
            penalty -= 0.15
        }
        if windKmh > 45 && sea > 1.2 {
            penalty -= 0.1
        }
        return penalty.clamped(to: 0.55...1.0)
    }

    // MARK: - Other dimensions

    private static func wetness(_ p: Double?) -> SubScore {
        guard let p else {
            return SubScore(value: 75, label: "Rain / squalls", detail: "Rain probability unknown.")
        }
        let v = 100 - p * 100
        return SubScore(
            value: v.clamped(to: 0...100),
            label: "Rain / squalls",
            detail: String(format: "Chance of rain ~%.0f%%.", p * 100)
        )
    }

    private static func visibility(_ km: Double?, cloud: Double?) -> SubScore {
        if let km {
            let v: Double = km >= 10 ? 95 : km >= 5 ? 78 : km >= 2 ? 52 : 25
            return SubScore(value: v, label: "Visibility / sky", detail: String(format: "Visibility ~%.0f km.", km))
        }
        if let c = cloud {
            let v = 100 - (c * 0.35)
            return SubScore(value: v.clamped(to: 0...100), label: "Visibility / sky", detail: String(format: "Cloud cover ~%.0f%%.", c))
        }
        return SubScore(value: 72, label: "Visibility / sky", detail: "Visibility not quantified.")
    }

    private static func thermalComfort(airC: Double?, uv: Double?) -> SubScore {
        guard let t = airC else {
            return SubScore(value: 75, label: "Thermal / sun", detail: "Temperature unknown.")
        }
        // Pleasant band roughly 18–28 °C on the water; cold vs hot simplified.
        let distance = abs(t - 22)
        let comfort = max(0, 28 - distance * 1.8)
        let uvPenalty = (uv ?? 5) * 2.5
        let v = (72 + comfort - uvPenalty).clamped(to: 0...100)
        let detail = String(format: "Air ~%.0f °C; UV factor applied if known.", t)
        return SubScore(value: v, label: "Thermal / sun", detail: detail)
    }

    private static func hazardKeywordPenalty(_ keywords: [String]) -> SubScore {
        guard !keywords.isEmpty else {
            return SubScore(value: 92, label: "Synoptic hazards", detail: "No extra hazard phrases detected.")
        }
        let bad = Set([
            "thunderstorm", "squall", "gale", "storm", "hazardous", "rough", "cyclone",
            "tsunami", "tornado", "severe"
        ])
        let hits = keywords.filter { kw in bad.contains { kw.contains($0) } }.count
        let v = max(15, 95 - Double(hits) * 22)
        return SubScore(
            value: v,
            label: "Synoptic hazards",
            detail: hits > 0 ? "Forecast text mentions elevated marine hazards." : "Minor phrasing only."
        )
    }

    // MARK: - Warnings

    private static func applyWarningCap(
        base: Double,
        warnings: [ScoringInput.MarineWarning]
    ) -> (Double, Bool, String?) {
        guard let maxSev = warnings.map(\.severity).max() else {
            return (base, false, nil)
        }
        let cap: Double
        let summary: String
        switch maxSev {
        case .advisory:
            cap = 72
            summary = "Marine advisory or minor warning active."
        case .strong:
            cap = 48
            summary = "Strong wind or related marine warning active."
        case .gale:
            cap = 28
            summary = "Gale or high-tier marine warning active."
        case .storm:
            cap = 12
            summary = "Storm-force or equivalent warning active."
        }
        let out = min(base, cap)
        let limited = out < base - 0.5
        let text = warnings.map(\.title).joined(separator: " · ")
        return (out, limited, summary + " " + text)
    }

    private static func buildDrivers(
        wind: SubScore,
        sea: SubScore,
        wet: SubScore,
        vis: SubScore,
        thermal: SubScore,
        hazard: SubScore,
        chopPenalty: Double,
        gustFactor: Double,
        warningLimited: Bool
    ) -> [String] {
        var out: [String] = []
        if warningLimited {
            out.append("Active BOM marine warnings cap the score.")
        }
        let subs = [wind, sea, wet, vis, thermal, hazard].sorted { $0.value < $1.value }
        for s in subs where s.value < 80 {
            out.append("\(s.label): \(s.detail)")
        }
        if chopPenalty < 0.95 {
            out.append("Short-period swell or wind-sea chop is reducing ride quality.")
        }
        if gustFactor > 1.2 {
            out.append("Gusts are notably stronger than the average wind.")
        }
        if out.isEmpty {
            out.append("Conditions look generally comfortable for casual boating.")
        }
        return Array(out.prefix(6))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
