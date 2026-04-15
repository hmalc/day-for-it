import Foundation

public enum QueenslandTideProviderError: Error {
    case noStationAvailable
    case stationPackageUnavailable
    case noResourceForRequiredYears
    case malformedCSV
}

public struct QueenslandTideDataProvider: TideDataProvider {
    private let session: URLSession
    private let calendar: Calendar

    public init(session: URLSession = .shared, calendar: Calendar = .current) {
        self.session = session
        self.calendar = calendar
    }

    public func fetchTideForecast(
        location: MarineLocation,
        start: Date,
        days: Int,
        sampleIntervalMinutes: Int?
    ) async throws -> TideForecast {
        let safeDays = max(1, days)
        guard let nearest = QueenslandTideStationManifest.nearest(latitude: location.latitude, longitude: location.longitude) else {
            throw QueenslandTideProviderError.noStationAvailable
        }

        let package = try await fetchPackage(named: nearest.station.packageName)
        let years = requiredYears(start: start, days: safeDays)
        var mergedEvents: [TideEventPoint] = []
        var mergedSamples: [TideSamplePoint] = []

        for year in years {
            guard let resourceURL = package.resourceURL(for: year) else { continue }
            let csvData = try await fetchData(url: resourceURL)
            let parsed = try parsePredictionCSV(csvData, timeZoneID: location.timeZoneID)
            mergedEvents.append(contentsOf: parsed.events)
            mergedSamples.append(contentsOf: parsed.samples)
        }

        guard !mergedSamples.isEmpty || !mergedEvents.isEmpty else {
            throw QueenslandTideProviderError.noResourceForRequiredYears
        }

        mergedEvents = uniqueSortedEvents(mergedEvents)
        mergedSamples = uniqueSortedSamples(mergedSamples)
        if mergedEvents.isEmpty, !mergedSamples.isEmpty {
            mergedEvents = deriveExtrema(from: mergedSamples)
        }

        let requestedStart = calendar.startOfDay(for: start)
        let requestedEnd = calendar.date(byAdding: .day, value: safeDays, to: requestedStart) ?? requestedStart
        let queryStart = calendar.date(byAdding: .hour, value: -6, to: requestedStart) ?? requestedStart
        let queryEnd = calendar.date(byAdding: .hour, value: 6, to: requestedEnd) ?? requestedEnd

        let scopedEvents = mergedEvents.filter { $0.time >= queryStart && $0.time <= queryEnd }
        let scopedSamples = mergedSamples.filter { $0.time >= queryStart && $0.time <= queryEnd }
        let interval = max(5, sampleIntervalMinutes ?? 20)

        var dayForecasts: [TideDayForecast] = []
        for offset in 0 ..< safeDays {
            guard
                let dayStart = calendar.date(byAdding: .day, value: offset, to: requestedStart),
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else { continue }

            let dayEvents = scopedEvents.filter { $0.time >= dayStart && $0.time < dayEnd }
            var daySamples = scopedSamples.filter { $0.time >= dayStart && $0.time < dayEnd }
            if daySamples.isEmpty, !dayEvents.isEmpty {
                daySamples = TideInterpolation.buildDerivedSamples(from: dayEvents, stepMinutes: interval)
            }
            dayForecasts.append(TideDayForecast(dayStart: dayStart, events: dayEvents, samples: daySamples))
        }

        let forecast = TideForecast(
            generatedAt: Date(),
            provider: "qld-open-data",
            locationName: location.name,
            stationName: nearest.station.displayName,
            stationDistanceKm: nearest.distanceKm,
            days: dayForecasts
        )
        return forecast
    }

    private func fetchPackage(named packageName: String) async throws -> QLDTidePackage {
        let endpoint = "https://www.data.qld.gov.au/api/3/action/package_show?id=\(packageName)"
        guard let url = URL(string: endpoint) else {
            throw QueenslandTideProviderError.stationPackageUnavailable
        }
        let data = try await fetchData(url: url)
        let decoded = try JSONDecoder().decode(QLDPackageShowEnvelope.self, from: data)
        guard decoded.success else {
            throw QueenslandTideProviderError.stationPackageUnavailable
        }
        return decoded.result
    }

    private func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("BoatPleasantness/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func requiredYears(start: Date, days: Int) -> [Int] {
        let startYear = calendar.component(.year, from: start)
        let end = calendar.date(byAdding: .day, value: days + 1, to: start) ?? start
        let endYear = calendar.component(.year, from: end)
        return Array(Set([startYear, endYear])).sorted()
    }

    private func parsePredictionCSV(_ data: Data, timeZoneID: String) throws -> (events: [TideEventPoint], samples: [TideSamplePoint]) {
        guard let text = String(data: data, encoding: .utf8) else {
            throw QueenslandTideProviderError.malformedCSV
        }
        var events: [TideEventPoint] = []
        var samples: [TideSamplePoint] = []
        var inReadings = false

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU_POSIX")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Australia/Brisbane")

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.contains("Date") && line.contains("Reading") {
                inReadings = true
                continue
            }
            guard inReadings else { continue }
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard columns.count >= 4 else { continue }
            let dateTimeRaw = "\(columns[0]) \(columns[1])"
            guard let date = formatter.date(from: dateTimeRaw), let reading = Double(columns[3]) else {
                continue
            }
            samples.append(
                TideSamplePoint(
                    time: date,
                    heightMeters: reading,
                    source: .authoritative
                )
            )
            if let indicator = Int(columns[2]) {
                if indicator == 1 {
                    events.append(TideEventPoint(time: date, kind: .high, heightMeters: reading, source: .authoritative))
                } else if indicator == -1 {
                    events.append(TideEventPoint(time: date, kind: .low, heightMeters: reading, source: .authoritative))
                }
            }
        }
        return (events, samples)
    }

    private func uniqueSortedEvents(_ values: [TideEventPoint]) -> [TideEventPoint] {
        var seen = Set<String>()
        return values
            .sorted { $0.time < $1.time }
            .filter { point in
                let key = "\(point.kind.rawValue)-\(Int(point.time.timeIntervalSince1970))"
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
    }

    private func uniqueSortedSamples(_ values: [TideSamplePoint]) -> [TideSamplePoint] {
        var seen = Set<Int>()
        return values
            .sorted { $0.time < $1.time }
            .filter { point in
                let key = Int(point.time.timeIntervalSince1970)
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
    }

    private func deriveExtrema(from samples: [TideSamplePoint]) -> [TideEventPoint] {
        guard samples.count >= 3 else { return [] }
        var out: [TideEventPoint] = []
        for idx in 1 ..< (samples.count - 1) {
            let prev = samples[idx - 1].heightMeters
            let cur = samples[idx].heightMeters
            let next = samples[idx + 1].heightMeters
            if cur >= prev, cur > next {
                out.append(TideEventPoint(time: samples[idx].time, kind: .high, heightMeters: cur, source: .derived))
            } else if cur <= prev, cur < next {
                out.append(TideEventPoint(time: samples[idx].time, kind: .low, heightMeters: cur, source: .derived))
            }
        }
        return out
    }
}

private struct QLDPackageShowEnvelope: Decodable {
    let success: Bool
    let result: QLDTidePackage
}

private struct QLDTidePackage: Decodable {
    struct Resource: Decodable {
        let name: String?
        let format: String?
        let url: String
    }

    let resources: [Resource]

    func resourceURL(for year: Int) -> URL? {
        let csvResources = resources.filter { ($0.format ?? "").caseInsensitiveCompare("csv") == .orderedSame }
        let match = csvResources.first {
            let haystack = "\($0.name ?? "") \($0.url)".lowercased()
            return haystack.contains("_\(year)_10min")
        } ?? csvResources.first {
            let haystack = "\($0.name ?? "") \($0.url)".lowercased()
            return haystack.contains("\(year)")
        }
        guard let raw = match?.url else { return nil }
        return URL(string: raw)
    }
}

private enum QueenslandTideStationManifest {
    struct Station: Sendable {
        let packageName: String
        let latitude: Double
        let longitude: Double

        var displayName: String {
            packageName
                .replacingOccurrences(of: "-tide-gauge-predicted-interval-data", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    struct NearestMatch: Sendable {
        let station: Station
        let distanceKm: Double
    }

    static let stations: [Station] = [
        .init(packageName: "abbot-point-tide-gauge-predicted-interval-data", latitude: -19.850000, longitude: 148.083333),
        .init(packageName: "amrun-tide-gauge-predicted-interval-data", latitude: -12.916667, longitude: 141.600000),
        .init(packageName: "aurukun-archer-river-tide-gauge-predicted-interval-data", latitude: -13.366667, longitude: 141.716667),
        .init(packageName: "badu-island-tide-gauge-predicted-interval-data", latitude: -10.166667, longitude: 142.166667),
        .init(packageName: "boigu-island-tide-gauge-predicted-interval-data", latitude: -9.216667, longitude: 142.216667),
        .init(packageName: "booby-island-tide-gauge-predicted-interval-data", latitude: -10.600000, longitude: 141.916667),
        .init(packageName: "bowen-tide-gauge-predicted-interval-data", latitude: -20.016667, longitude: 148.250000),
        .init(packageName: "brisbane-bar-tide-gauge-predicted-interval-data", latitude: -27.400000, longitude: 153.150000),
        .init(packageName: "bugatti-reef-outer-tide-gauge-predicted-interval-data", latitude: -20.083333, longitude: 150.300000),
        .init(packageName: "bundaberg-tide-gauge-predicted-interval-data", latitude: -24.766667, longitude: 152.366667),
        .init(packageName: "burnett-heads-tide-gauge-predicted-interval-data", latitude: -24.750000, longitude: 152.400000),
        .init(packageName: "cairns-beacon-c1-tide-gauge-predicted-interval-data", latitude: -16.816667, longitude: 145.816667),
        .init(packageName: "cairns-tide-gauge-predicted-interval-data", latitude: -16.916667, longitude: 145.766667),
        .init(packageName: "cape-ferguson-tide-gauge-predicted-interval-data", latitude: -19.266667, longitude: 147.050000),
        .init(packageName: "cape-flattery-tide-gauge-predicted-interval-data", latitude: -14.950000, longitude: 145.300000),
        .init(packageName: "cardwell-tide-gauge-predicted-interval-data", latitude: -18.250000, longitude: 146.016667),
        .init(packageName: "clump-point-tide-gauge-predicted-interval-data", latitude: -17.850000, longitude: 146.100000),
        .init(packageName: "coconut-island-poruma-tide-gauge-predicted-interval-data", latitude: -10.033333, longitude: 143.050000),
        .init(packageName: "cooktown-tide-gauge-predicted-interval-data", latitude: -15.450000, longitude: 145.233333),
        .init(packageName: "darnley-island-erub-tide-gauge-predicted-interval-data", latitude: -9.583333, longitude: 143.750000),
        .init(packageName: "dauan-island-tide-gauge-predicted-interval-data", latitude: -9.400000, longitude: 142.533333),
        .init(packageName: "deep-water-bend-pine-river-tide-gauge-predicted-interval-data", latitude: -27.283333, longitude: 153.033333),
        .init(packageName: "fisherman-s-landing-tide-gauge-predicted-interval-data", latitude: -23.783333, longitude: 151.166667),
        .init(packageName: "gladstone-auckland-point-tide-gauge-predicted-interval-data", latitude: -23.816667, longitude: 151.250000),
        .init(packageName: "gold-coast-seaway-tide-gauge-predicted-interval-data", latitude: -27.933333, longitude: 153.416667),
        .init(packageName: "golding-reciprocal-f-l-gladstone-tide-gauge-predicted-interval-data", latitude: -23.933333, longitude: 151.450000),
        .init(packageName: "goods-island-tide-gauge-predicted-interval-data", latitude: -10.566667, longitude: 142.150000),
        .init(packageName: "half-tide-tug-harbour-tide-gauge-predicted-interval-data", latitude: -21.283333, longitude: 149.300000),
        .init(packageName: "hammond-island-tide-gauge-predicted-interval-data", latitude: -10.550000, longitude: 142.216667),
        .init(packageName: "hay-point-tide-gauge-predicted-interval-data", latitude: -21.266667, longitude: 149.300000),
        .init(packageName: "inscription-point-sweers-island-tide-gauge-predicted-interval-data", latitude: -17.100000, longitude: 139.583333),
        .init(packageName: "karumba-bar-tide-gauge-predicted-interval-data", latitude: -17.416667, longitude: 140.716667),
        .init(packageName: "karumba-tide-gauge-predicted-interval-data", latitude: -17.483333, longitude: 140.833333),
        .init(packageName: "kingfisher-bay-jetty-tide-gauge-predicted-interval-data", latitude: -25.383333, longitude: 153.016667),
        .init(packageName: "kubin-moa-island-tide-gauge-predicted-interval-data", latitude: -10.233333, longitude: 142.200000),
        .init(packageName: "leggatt-island-tide-gauge-predicted-interval-data", latitude: -14.516667, longitude: 144.850000),
        .init(packageName: "lizard-island-tide-gauge-predicted-interval-data", latitude: -14.666667, longitude: 145.433333),
        .init(packageName: "lucinda-tide-gauge-predicted-interval-data", latitude: -18.516667, longitude: 146.383333),
        .init(packageName: "mabuiag-island-tide-gauge-predicted-interval-data", latitude: -9.950000, longitude: 142.200000),
        .init(packageName: "mackay-tide-gauge-predicted-interval-data", latitude: -21.100000, longitude: 149.216667),
        .init(packageName: "mooloolaba-tide-gauge-predicted-interval-data", latitude: -26.683333, longitude: 153.133333),
        .init(packageName: "mornington-island-tide-gauge-predicted-interval-data", latitude: -16.666667, longitude: 139.166667),
        .init(packageName: "mossman-tide-gauge-predicted-interval-data", latitude: -16.416667, longitude: 145.400000),
        .init(packageName: "mourilyan-tide-gauge-predicted-interval-data", latitude: -17.583333, longitude: 146.116667),
        .init(packageName: "murray-island-meer-tide-gauge-predicted-interval-data", latitude: -9.900000, longitude: 144.033333),
        .init(packageName: "no-2-beacon-weipa-tide-gauge-predicted-interval-data", latitude: -12.683333, longitude: 141.700000),
        .init(packageName: "noosa-head-tide-gauge-predicted-interval-data", latitude: -26.383333, longitude: 153.100000),
        .init(packageName: "north-cardinal-beacon-townsville-tide-gauge-predicted-interval-data", latitude: -19.116667, longitude: 146.900000),
        .init(packageName: "pinkenba-tide-gauge-predicted-interval-data", latitude: -27.416667, longitude: 153.116667),
        .init(packageName: "port-alma-tide-gauge-predicted-interval-data", latitude: -23.583333, longitude: 150.850000),
        .init(packageName: "port-douglas-tide-gauge-predicted-interval-data", latitude: -16.483333, longitude: 145.450000),
        .init(packageName: "port-office-brisbane-river-tide-gauge-predicted-interval-data", latitude: -27.466667, longitude: 153.016667),
        .init(packageName: "portland-roads-tide-gauge-predicted-interval-data", latitude: -12.583333, longitude: 143.400000),
        .init(packageName: "red-island-point-bamaga-tide-gauge-predicted-interval-data", latitude: -10.833333, longitude: 142.366667),
        .init(packageName: "rockhampton-tide-gauge-predicted-interval-data", latitude: -23.366667, longitude: 150.516667),
        .init(packageName: "rosslyn-bay-tide-gauge-predicted-interval-data", latitude: -23.150000, longitude: 150.783333),
        .init(packageName: "saibai-island-tide-gauge-predicted-interval-data", latitude: -9.366667, longitude: 142.600000),
        .init(packageName: "scarborough-tide-gauge-predicted-interval-data", latitude: -27.183333, longitude: 153.100000),
        .init(packageName: "shorncliffe-tide-gauge-predicted-interval-data", latitude: -27.316667, longitude: 153.083333),
        .init(packageName: "shute-harbour-tide-gauge-predicted-interval-data", latitude: -20.283333, longitude: 148.783333),
        .init(packageName: "skardon-river-offshore-tide-gauge-predicted-interval-data", latitude: -11.750000, longitude: 141.983333),
        .init(packageName: "skardon-river-tide-gauge-predicted-interval-data", latitude: -11.750000, longitude: 142.066667),
        .init(packageName: "south-trees-tide-gauge-predicted-interval-data", latitude: -23.850000, longitude: 151.300000),
        .init(packageName: "southport-tide-gauge-predicted-interval-data", latitude: -27.966667, longitude: 153.416667),
        .init(packageName: "st-pauls-moa-island-tide-gauge-predicted-interval-data", latitude: -10.183333, longitude: 142.333333),
        .init(packageName: "stephens-island-ugar-tide-gauge-predicted-interval-data", latitude: -9.500000, longitude: 143.533333),
        .init(packageName: "sue-island-warraber-tide-gauge-predicted-interval-data", latitude: -10.200000, longitude: 142.816667),
        .init(packageName: "tangalooma-tide-gauge-predicted-interval-data", latitude: -27.166667, longitude: 153.366667),
        .init(packageName: "thursday-island-tide-gauge-predicted-interval-data", latitude: -10.583333, longitude: 142.216667),
        .init(packageName: "tin-can-bay-snapper-creek-tide-gauge-predicted-interval-data", latitude: -25.900000, longitude: 153.000000),
        .init(packageName: "townsville-tide-gauge-predicted-interval-data", latitude: -19.233333, longitude: 146.833333),
        .init(packageName: "twin-island-tide-gauge-predicted-interval-data", latitude: -10.466667, longitude: 142.433333),
        .init(packageName: "urangan-fairway-beacon-tide-gauge-predicted-interval-data", latitude: -25.133333, longitude: 152.816667),
        .init(packageName: "urangan-tide-gauge-predicted-interval-data", latitude: -25.283333, longitude: 152.900000),
        .init(packageName: "waddy-point-k-gari-tide-gauge-predicted-interval-data", latitude: -24.966667, longitude: 153.350000),
        .init(packageName: "weipa-tide-gauge-predicted-interval-data", latitude: -12.666667, longitude: 141.850000),
        .init(packageName: "yam-island-iama-tide-gauge-predicted-interval-data", latitude: -9.900000, longitude: 142.766667),
        .init(packageName: "yorke-island-masig-tide-gauge-predicted-interval-data", latitude: -9.733333, longitude: 143.400000),
    ]

    static func nearest(latitude: Double, longitude: Double) -> NearestMatch? {
        guard let station = stations.min(by: {
            distanceKm(fromLat: latitude, fromLon: longitude, toLat: $0.latitude, toLon: $0.longitude) <
                distanceKm(fromLat: latitude, fromLon: longitude, toLat: $1.latitude, toLon: $1.longitude)
        }) else {
            return nil
        }
        let distance = distanceKm(fromLat: latitude, fromLon: longitude, toLat: station.latitude, toLon: station.longitude)
        return NearestMatch(station: station, distanceKm: distance)
    }

    private static func distanceKm(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) -> Double {
        let radiusKm = 6371.0
        let dLat = (toLat - fromLat) * .pi / 180
        let dLon = (toLon - fromLon) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(fromLat * .pi / 180) * cos(toLat * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        return 2 * radiusKm * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}
