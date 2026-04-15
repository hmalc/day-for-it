import Foundation
import PleasantnessEngine

public struct MarineSnapshotAssembler {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func assembleSnapshot(
        location: BoatingLocation,
        forecast: [MarineForecast],
        observations: [MarineObservation],
        tides: [TidePrediction],
        warnings: [MarineWarning]
    ) -> MarineSnapshot {
        MarineSnapshot(
            locationID: location.id,
            asOfUTC: Date(),
            forecast: forecast,
            observations: observations,
            tides: tides,
            waveForecasts: [],
            waveObservations: [],
            warnings: warnings
        )
    }

    public func buildAssessmentInputs(snapshot: MarineSnapshot, forecastDays: Int) -> [AssessmentInput] {
        let day0 = calendar.startOfDay(for: Date())
        return (0 ..< max(1, forecastDays)).compactMap { offset in
            guard
                let start = calendar.date(byAdding: .day, value: offset, to: day0),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else { return nil }

            let window = ValidityWindow(startUTC: start, endUTC: end)
            let dayForecast = snapshot.forecast.first { item in
                item.validFor.startUTC < end && item.validFor.endUTC > start
            }
            let dayTide = snapshot.tides.first { item in
                item.window.startUTC < end && item.window.endUTC > start
            }

            let warningSeverity = strongestWarningSeverity(snapshot.warnings)
            var provenanceRefs: [ProvenanceRef] = []
            if let p = dayForecast?.provenance { provenanceRefs.append(p) }
            if let p = dayTide?.provenance { provenanceRefs.append(p) }
            if let p = snapshot.warnings.first?.provenance { provenanceRefs.append(p) }

            return AssessmentInput(
                locationID: snapshot.locationID,
                targetWindow: window,
                forecastWindKmh: dayForecast?.windSpeedKmh ?? FieldValue(value: nil, state: .missing, reason: "No forecast period"),
                tideSuitability: dayTide?.suitability ?? FieldValue(value: nil, state: .notProvided, reason: "No tide prediction"),
                rainProbability: dayForecast?.rainfallProb ?? FieldValue(value: nil, state: .unknown),
                warningSeverity: warningSeverity,
                provenanceRefs: provenanceRefs
            )
        }
    }

    public func toLegacyOutput(
        requestLocation: MarineLocation,
        snapshot: MarineSnapshot,
        assessmentInputs: [AssessmentInput],
        forecastDays: Int
    ) -> MarineForecastOutput {
        let daily = assessmentInputs.prefix(max(1, forecastDays)).map { input in
            let warning = input.warningSeverity.value
            let hasStrongWarning = warning == .strong || warning == .severe

            let score = BoatDayScorer.score(
                windKmh: input.forecastWindKmh.value,
                tideSuitability: input.tideSuitability.value,
                rainProbability: input.rainProbability.value,
                hasStrongWarning: hasStrongWarning
            )

            var drivers = score.reasons
            if let tideSummary = snapshot.tides.first(where: { $0.window.startUTC <= input.targetWindow.startUTC && $0.window.endUTC > input.targetWindow.startUTC })?.summary {
                drivers.append(tideSummary)
            }

            let available = input.forecastWindKmh.value != nil || input.tideSuitability.value != nil
            return DailyMarineSummary(
                dayStart: input.targetWindow.startUTC,
                pleasantness: available ? score.score : nil,
                rating: available ? score.rating : .amber,
                availability: available ? .available : .unavailable,
                confidence: available ? "medium" : "low",
                warningLimited: hasStrongWarning,
                topDrivers: Array(drivers.prefix(3))
            )
        }

        let warnings = snapshot.warnings.map { warning in
            MarineWarningItem(title: warning.headline, link: warning.provenance.rawPayloadRef ?? "")
        }
        let degradedReason = snapshot.tides.isEmpty ? "Using BOM wind/weather only; tide provider unavailable." : nil
        let dataQuality: MarineForecastOutput.DataQuality = snapshot.tides.isEmpty ? .bomFallback : .hybrid

        return MarineForecastOutput(
            location: requestLocation,
            generatedAt: Date(),
            hourly: [],
            daily: daily,
            warnings: warnings,
            coastalExcerpt: nil,
            dataQuality: dataQuality,
            degradedReason: degradedReason
        )
    }

    static func heuristicRainProbability(from text: String) -> Double? {
        let lower = text.lowercased()
        if lower.contains("thunderstorm") { return 0.75 }
        if lower.contains("showers") { return 0.55 }
        if lower.contains("rain") { return 0.5 }
        if lower.contains("cloudy") { return 0.25 }
        return 0.1
    }

    private func strongestWarningSeverity(_ warnings: [MarineWarning]) -> FieldValue<MarineWarningSeverity> {
        guard let top = warnings.map(\.severity).max(by: severityRank) else {
            return FieldValue(value: nil, state: .notProvided, reason: "No warnings feed")
        }
        return FieldValue(value: top, state: .available)
    }

    private func severityRank(lhs: MarineWarningSeverity, rhs: MarineWarningSeverity) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private func rank(_ severity: MarineWarningSeverity) -> Int {
        switch severity {
        case .minor: return 0
        case .strong: return 1
        case .severe: return 2
        }
    }
}
