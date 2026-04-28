import Foundation
import PleasantnessEngine

public struct MarineSnapshotAssembler: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func assembleSnapshot(
        location: BoatingLocation,
        forecast: [MarineForecast],
        observations: [MarineObservation],
        tides: [TidePrediction],
        warnings: [MarineWarning],
        waveForecasts: [WaveForecast] = [],
        waveObservations: [WaveObservation] = []
    ) -> MarineSnapshot {
        MarineSnapshot(
            locationID: location.id,
            asOfUTC: Date(),
            forecast: forecast,
            observations: observations,
            tides: tides,
            waveForecasts: waveForecasts,
            waveObservations: waveObservations,
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
            let dayObservation = latestObservation(in: snapshot.observations, for: window, asOf: snapshot.asOfUTC)
            let dayWaveForecast = snapshot.waveForecasts.first { item in
                item.validFor.startUTC < end && item.validFor.endUTC > start
            }
            let dayWaveObservation = latestWaveObservation(in: snapshot.waveObservations, for: window, asOf: snapshot.asOfUTC)

            let relevantWarnings = warnings(in: snapshot.warnings, for: window, asOf: snapshot.asOfUTC)
            let warningSeverity = strongestWarningSeverity(relevantWarnings)
            var provenanceRefs: [ProvenanceRef] = []
            if let p = dayForecast?.provenance { provenanceRefs.append(p) }
            if let p = dayObservation?.provenance { provenanceRefs.append(p) }
            if let p = dayTide?.provenance { provenanceRefs.append(p) }
            if let p = dayWaveForecast?.provenance { provenanceRefs.append(p) }
            if let p = dayWaveObservation?.provenance { provenanceRefs.append(p) }
            if let p = relevantWarnings.first?.provenance { provenanceRefs.append(p) }

            let waveHeight = waveHeightField(
                forecast: dayForecast,
                waveForecast: dayWaveForecast,
                waveObservation: dayWaveObservation
            )
            let wavePeriod = dayWaveObservation?.peakPeriodS ?? dayWaveForecast?.peakPeriodS ?? FieldValue(value: nil, state: .notProvided)
            let seaSurfaceTemp = dayWaveObservation?.seaSurfaceTempC ?? FieldValue(value: nil, state: .notProvided)

            return AssessmentInput(
                locationID: snapshot.locationID,
                targetWindow: window,
                forecastWindKmh: dayForecast?.windSpeedKmh ?? FieldValue(value: nil, state: .missing, reason: "No forecast period"),
                tideSuitability: dayTide?.suitability ?? FieldValue(value: nil, state: .notProvided, reason: "No tide prediction"),
                rainProbability: dayForecast?.rainfallProb ?? FieldValue(value: nil, state: .unknown),
                warningSeverity: warningSeverity,
                provenanceRefs: provenanceRefs,
                observedWindKmh: dayObservation?.windSpeedKmh ?? FieldValue(value: nil, state: .notProvided),
                observedWindGustKmh: dayObservation?.windGustKmh ?? FieldValue(value: nil, state: .notProvided),
                waveHeightM: waveHeight,
                swellHeightM: dayForecast?.swellHeightM ?? FieldValue(value: nil, state: .notProvided),
                wavePeriodS: wavePeriod,
                seaSurfaceTempC: seaSurfaceTemp
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
            let matchingForecast = snapshot.forecast.first { item in
                item.validFor.startUTC < input.targetWindow.endUTC && item.validFor.endUTC > input.targetWindow.startUTC
            }

            let windForScore = maxAvailable(input.forecastWindKmh.value, input.observedWindKmh.value)
            let waveForScore = maxAvailable(input.waveHeightM.value, matchingForecast?.waveHeightM.value)
            let score = BoatDayScorer.score(
                windKmh: windForScore,
                windGustKmh: input.observedWindGustKmh.value,
                tideSuitability: input.tideSuitability.value,
                rainProbability: input.rainProbability.value,
                hasStrongWarning: hasStrongWarning,
                waveHeightM: waveForScore,
                swellHeightM: input.swellHeightM.value,
                wavePeriodS: input.wavePeriodS.value
            )

            var drivers = quantifiedDrivers(input: input) + score.reasons
            if let tideSummary = snapshot.tides.first(where: { $0.window.startUTC <= input.targetWindow.startUTC && $0.window.endUTC > input.targetWindow.startUTC })?.summary {
                drivers.append(tideSummary)
            }

            let hasWind = windForScore != nil
            let hasTide = input.tideSuitability.value != nil
            let hasSea = waveForScore != nil
            let hasRain = input.rainProbability.value != nil
            let signalCount = [hasWind, hasTide, hasSea, hasRain].filter { $0 }.count
            let available = matchingForecast != nil || hasTide
            let confidence = signalCount >= 3 ? "high" : signalCount >= 2 ? "medium" : "low"
            return DailyMarineSummary(
                dayStart: input.targetWindow.startUTC,
                pleasantness: available ? score.score : nil,
                rating: available ? score.rating : .amber,
                availability: available ? .available : .unavailable,
                confidence: confidence,
                warningLimited: hasStrongWarning,
                topDrivers: drivers
            )
        }

        let warnings = snapshot.warnings.map { warning in
            MarineWarningItem(title: warning.headline, link: warning.provenance.rawPayloadRef ?? "")
        }
        let degradedReason = snapshot.tides.isEmpty ? "Official tide data unavailable; using Bureau marine forecast and warnings only." : nil
        let dataQuality: MarineForecastOutput.DataQuality = snapshot.tides.isEmpty ? .officialForecastOnly : .official

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

    private func warnings(in warnings: [MarineWarning], for window: ValidityWindow, asOf: Date) -> [MarineWarning] {
        warnings.filter { warning in
            if let validWindow = warning.validWindow {
                return validWindow.startUTC < window.endUTC && validWindow.endUTC > window.startUTC
            }
            return calendar.isDate(window.startUTC, inSameDayAs: asOf)
        }
    }

    private func latestObservation(in observations: [MarineObservation], for window: ValidityWindow, asOf: Date) -> MarineObservation? {
        let cutoff = calendar.date(byAdding: .hour, value: -6, to: asOf) ?? asOf
        return observations
            .filter { $0.observedAtUTC >= window.startUTC && $0.observedAtUTC < window.endUTC && $0.observedAtUTC >= cutoff }
            .max { $0.observedAtUTC < $1.observedAtUTC }
    }

    private func latestWaveObservation(in observations: [WaveObservation], for window: ValidityWindow, asOf: Date) -> WaveObservation? {
        let cutoff = calendar.date(byAdding: .hour, value: -6, to: asOf) ?? asOf
        return observations
            .filter { $0.observedAtUTC >= window.startUTC && $0.observedAtUTC < window.endUTC && $0.observedAtUTC >= cutoff }
            .max { $0.observedAtUTC < $1.observedAtUTC }
    }

    private func waveHeightField(
        forecast: MarineForecast?,
        waveForecast: WaveForecast?,
        waveObservation: WaveObservation?
    ) -> FieldValue<Double> {
        [
            forecast?.waveHeightM,
            waveForecast?.significantHeightM,
            waveObservation?.significantHeightM,
        ]
        .compactMap { $0 }
        .max { ($0.value ?? -.infinity) < ($1.value ?? -.infinity) }
        ?? FieldValue(value: nil, state: .notProvided)
    }

    private func quantifiedDrivers(input: AssessmentInput) -> [String] {
        var drivers: [String] = []
        if let forecastWind = input.forecastWindKmh.value, let observedWind = input.observedWindKmh.value {
            if forecastWind >= observedWind {
                drivers.append("Forecast wind up to \(Int(forecastWind.rounded())) km/h")
                drivers.append(observedWindDriver(input: input, wind: observedWind))
            } else {
                drivers.append(observedWindDriver(input: input, wind: observedWind))
                drivers.append("Forecast wind up to \(Int(forecastWind.rounded())) km/h")
            }
        } else if let wind = input.observedWindKmh.value {
            drivers.append(observedWindDriver(input: input, wind: wind))
        } else if let wind = input.forecastWindKmh.value {
            drivers.append("Forecast wind up to \(Int(wind.rounded())) km/h")
        }

        if let wave = input.waveHeightM.value {
            let prefix = input.waveHeightM.reason?.localizedCaseInsensitiveContains("observed") == true ? "Observed waves" : "Forecast seas"
            drivers.append("\(prefix) \(String(format: "%.1f", wave)) m")
        }
        if let swell = input.swellHeightM.value {
            drivers.append("Forecast swell \(String(format: "%.1f", swell)) m")
        }
        if let period = input.wavePeriodS.value {
            drivers.append("Peak wave period \(String(format: "%.0f", period)) s")
        }
        if let seaTemp = input.seaSurfaceTempC.value {
            drivers.append("Sea surface \(String(format: "%.1f", seaTemp)) C")
        }
        return drivers
    }

    private func observedWindDriver(input: AssessmentInput, wind: Double) -> String {
        if let gust = input.observedWindGustKmh.value {
            return "Observed wind \(Int(wind.rounded())) km/h, gusting \(Int(gust.rounded())) km/h"
        }
        return "Observed wind \(Int(wind.rounded())) km/h"
    }

    private func maxAvailable(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
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
