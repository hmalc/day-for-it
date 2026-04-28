import Foundation

public enum QueenslandWaveProviderError: Error {
    case malformedCSV
}

public struct QueenslandWaveDataProvider: WaveProvider, Sendable {
    static let nearRealTimeResourceURL = URL(string: "https://apps.des.qld.gov.au/data-sets/waves/wave-7dayopdata.csv")!
    private static let maximumNearestBuoyDistanceKm = 250.0

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchWaveForecast(location: BoatingLocation, days: Int) async throws -> [WaveForecast] {
        []
    }

    public func fetchWaveObservation(location: BoatingLocation) async throws -> [WaveObservation] {
        let fetchedAt = Date()
        let data = try await fetchData(url: Self.nearRealTimeResourceURL)
        let records = try Self.parseWaveCSV(data)
        guard let record = Self.bestRecord(for: location, from: records) else { return [] }
        let parsedAt = Date()

        return [
            WaveObservation(
                locationID: location.id,
                observedAtUTC: record.observedAtUTC,
                significantHeightM: FieldValue(value: record.significantHeightM, state: record.significantHeightM == nil ? .missing : .available, reason: "Observed at \(record.site) wave buoy"),
                maximumHeightM: FieldValue(value: record.maximumHeightM, state: record.maximumHeightM == nil ? .missing : .available),
                peakPeriodS: FieldValue(value: record.peakPeriodS, state: record.peakPeriodS == nil ? .missing : .available),
                zeroCrossingPeriodS: FieldValue(value: record.zeroCrossingPeriodS, state: record.zeroCrossingPeriodS == nil ? .missing : .available),
                directionDeg: FieldValue(value: record.directionDeg, state: record.directionDeg == nil ? .missing : .available),
                seaSurfaceTempC: FieldValue(value: record.seaSurfaceTempC, state: record.seaSurfaceTempC == nil ? .missing : .available, reason: "Observed at \(record.site) wave buoy"),
                freshness: Self.freshness(for: record.observedAtUTC, fetchedAt: fetchedAt),
                provenance: ProvenanceRef(
                    provider: "qld-open-data",
                    product: "coastal-data-system-near-real-time-wave-data",
                    sourceObjectID: record.sourceObjectID,
                    fetchedAtUTC: fetchedAt,
                    parsedAtUTC: parsedAt,
                    rawPayloadRef: Self.nearRealTimeResourceURL.absoluteString
                )
            ),
        ]
    }

    func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("dayforit/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/csv, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    static func parseWaveCSV(_ data: Data) throws -> [QueenslandWaveRecord] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw QueenslandWaveProviderError.malformedCSV
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("Site,") }) else {
            throw QueenslandWaveProviderError.malformedCSV
        }
        let headers = splitCSVRow(lines[headerIndex])
        guard !headers.isEmpty else { throw QueenslandWaveProviderError.malformedCSV }

        var records: [QueenslandWaveRecord] = []
        for line in lines.dropFirst(headerIndex + 1) {
            let values = splitCSVRow(line)
            guard values.count >= headers.count else { continue }
            let row = Dictionary(uniqueKeysWithValues: zip(headers, values))
            guard
                let site = nonEmpty(row["Site"]),
                let observedAt = observedDate(seconds: row["Seconds"], dateTime: row["DateTime"]),
                let latitude = numeric(row["Latitude"]),
                let longitude = numeric(row["Longitude"])
            else { continue }

            records.append(
                QueenslandWaveRecord(
                    site: site,
                    siteNumber: nonEmpty(row["SiteNumber"]),
                    observedAtUTC: observedAt,
                    latitude: latitude,
                    longitude: longitude,
                    significantHeightM: measurement(row["Hsig"]),
                    maximumHeightM: measurement(row["Hmax"]),
                    peakPeriodS: measurement(row["Tp"]),
                    zeroCrossingPeriodS: measurement(row["Tz"]),
                    seaSurfaceTempC: measurement(row["SST"]),
                    directionDeg: measurement(row["Direction"])
                )
            )
        }
        return records
    }

    static func bestRecord(for location: BoatingLocation, from records: [QueenslandWaveRecord]) -> QueenslandWaveRecord? {
        let latestRecords = latestRecordPerSite(from: records)
        if let bound = nonEmpty(location.bindings.waveBuoyID) {
            let normalizedBound = normalize(bound)
            if let exact = latestRecords.first(where: { record in
                normalize(record.site) == normalizedBound || normalize(record.siteNumber ?? "") == normalizedBound
            }) {
                return exact
            }
        }

        guard let nearest = latestRecords.min(by: {
            distanceKm(fromLat: location.latitude, fromLon: location.longitude, toLat: $0.latitude, toLon: $0.longitude) <
                distanceKm(fromLat: location.latitude, fromLon: location.longitude, toLat: $1.latitude, toLon: $1.longitude)
        }) else {
            return nil
        }
        let distance = distanceKm(fromLat: location.latitude, fromLon: location.longitude, toLat: nearest.latitude, toLon: nearest.longitude)
        return distance <= maximumNearestBuoyDistanceKm ? nearest : nil
    }

    private static func latestRecordPerSite(from records: [QueenslandWaveRecord]) -> [QueenslandWaveRecord] {
        var latest: [String: QueenslandWaveRecord] = [:]
        for record in records {
            let key = normalize(record.siteNumber ?? record.site)
            if let existing = latest[key], existing.observedAtUTC >= record.observedAtUTC {
                continue
            }
            latest[key] = record
        }
        return Array(latest.values)
    }

    private static func observedDate(seconds: String?, dateTime: String?) -> Date? {
        if let rawSeconds = nonEmpty(seconds), let epoch = TimeInterval(rawSeconds), epoch > 0 {
            return Date(timeIntervalSince1970: epoch)
        }
        guard let dateTime = nonEmpty(dateTime) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Brisbane")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: dateTime)
    }

    private static func splitCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                let next = line.index(after: index)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if char == ",", !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }

        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    private static func nonEmpty(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func numeric(_ raw: String?) -> Double? {
        guard let value = nonEmpty(raw) else { return nil }
        return Double(value)
    }

    private static func measurement(_ raw: String?) -> Double? {
        guard let value = numeric(raw), value > -90 else { return nil }
        return value
    }

    private static func freshness(for observedAt: Date, fetchedAt: Date) -> FreshnessStatus {
        let age = fetchedAt.timeIntervalSince(observedAt)
        if age >= 0, age <= 3 * 60 * 60 { return .fresh }
        return .stale
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
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

struct QueenslandWaveRecord: Sendable, Equatable {
    var site: String
    var siteNumber: String?
    var observedAtUTC: Date
    var latitude: Double
    var longitude: Double
    var significantHeightM: Double?
    var maximumHeightM: Double?
    var peakPeriodS: Double?
    var zeroCrossingPeriodS: Double?
    var seaSurfaceTempC: Double?
    var directionDeg: Double?

    var sourceObjectID: String {
        if let siteNumber, !siteNumber.isEmpty {
            return "\(site) (\(siteNumber))"
        }
        return site
    }
}
