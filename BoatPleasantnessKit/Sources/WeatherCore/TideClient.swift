import Foundation

public enum TideClientError: Error {
    case missingAPIKey
    case invalidResponse
}

private struct WorldTidesResponse: Decodable {
    struct Extreme: Decodable {
        let dt: Int
        let type: String
        let height: Double?
    }

    struct HeightPoint: Decodable {
        let dt: Int
        let height: Double
    }
    let extremes: [Extreme]?
    let heights: [HeightPoint]?
}

/// Simple third-party tide client. Requires WorldTides key in init.
public struct TideClient: TideDataProvider {
    private let session: URLSession
    private let apiKey: String?

    public init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func fetchDailySummaries(location: MarineLocation, days: Int) async throws -> [Date: TideDaySummary] {
        let forecast = try await fetchTideForecast(
            location: location,
            start: Date(),
            days: days,
            sampleIntervalMinutes: nil
        )

        var byDay: [Date: [WorldTidesResponse.Extreme]] = [:]
        for day in forecast.days {
            for event in day.events {
                let d = event.time
                let type = event.kind == .high ? "high" : "low"
                let raw = WorldTidesResponse.Extreme(dt: Int(d.timeIntervalSince1970), type: type, height: event.heightMeters)
                let dayKey = Calendar.current.startOfDay(for: d)
                byDay[dayKey, default: []].append(raw)
            }
        }

        var out: [Date: TideDaySummary] = [:]
        for (day, points) in byDay {
            let highs = points.filter { $0.type.lowercased().contains("high") }.count
            let lows = points.filter { $0.type.lowercased().contains("low") }.count
            // For v1 we treat at least one high and one low as more favorable.
            let suitability = (highs > 0 && lows > 0) ? 0.75 : (highs + lows > 0 ? 0.5 : 0.25)
            let summary = highs > 0 && lows > 0 ? "Two-way tide movement" : "Limited tide movement"
            out[day] = TideDaySummary(suitability: suitability, summary: summary)
        }
        return out
    }

    public func fetchTideForecast(
        location: MarineLocation,
        start: Date,
        days: Int,
        sampleIntervalMinutes: Int? = nil
    ) async throws -> TideForecast {
        guard let key = apiKey, !key.isEmpty else {
            throw TideClientError.missingAPIKey
        }
        let calendar = Calendar.current
        let safeDays = max(1, days)
        let requestStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start
        let requestedEnd = calendar.date(byAdding: .day, value: safeDays, to: start) ?? start
        let requestEnd = calendar.date(byAdding: .hour, value: 12, to: requestedEnd) ?? requestedEnd

        var c = URLComponents(string: "https://www.worldtides.info/api/v3")!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "extremes", value: ""),
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "start", value: String(Int(requestStart.timeIntervalSince1970))),
            URLQueryItem(name: "end", value: String(Int(requestEnd.timeIntervalSince1970))),
            URLQueryItem(name: "key", value: key),
        ]
        if let interval = sampleIntervalMinutes, interval > 0 {
            query.append(URLQueryItem(name: "heights", value: ""))
            query.append(URLQueryItem(name: "step", value: String(interval * 60)))
        }
        c.queryItems = query
        guard let url = c.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw TideClientError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(WorldTidesResponse.self, from: data)

        let normalizedEvents: [TideEventPoint] = (decoded.extremes ?? []).compactMap { e in
            let lower = e.type.lowercased()
            let kind: TideExtremaKind?
            if lower.contains("high") {
                kind = .high
            } else if lower.contains("low") {
                kind = .low
            } else {
                kind = nil
            }
            guard let kind else { return nil }
            return TideEventPoint(
                time: Date(timeIntervalSince1970: Double(e.dt)),
                kind: kind,
                heightMeters: e.height,
                source: .authoritative
            )
        }
        .sorted { $0.time < $1.time }

        let sampledSeries: [TideSamplePoint] = (decoded.heights ?? []).map { point in
            TideSamplePoint(
                time: Date(timeIntervalSince1970: Double(point.dt)),
                heightMeters: point.height,
                source: .authoritative
            )
        }
        .sorted { $0.time < $1.time }

        var daysOut: [TideDayForecast] = []
        for offset in 0 ..< safeDays {
            guard
                let dayStart = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)),
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else { continue }
            let dayEvents = normalizedEvents.filter { $0.time >= dayStart && $0.time < dayEnd }
            let daySamplesRaw = sampledSeries.filter { $0.time >= dayStart && $0.time < dayEnd }
            let samples: [TideSamplePoint]
            if daySamplesRaw.isEmpty {
                samples = TideInterpolation.buildDerivedSamples(from: dayEvents, stepMinutes: sampleIntervalMinutes ?? 20)
            } else {
                samples = daySamplesRaw
            }
            daysOut.append(TideDayForecast(dayStart: dayStart, events: dayEvents, samples: samples))
        }

        return TideForecast(
            generatedAt: Date(),
            provider: "worldtides",
            locationName: location.name,
            days: daysOut
        )
    }
}
