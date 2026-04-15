import Foundation

public enum OpenMeteoClientError: Error {
    case emptySeries
}

public struct OpenMeteoHourlyPoint: Sendable, Equatable {
    public var time: Date
    public var temperatureC: Double?
    public var windSpeedKmh: Double?
    public var windGustKmh: Double?
    public var precipitationProbability: Double?
    public var cloudCoverPercent: Double?

    public init(
        time: Date,
        temperatureC: Double? = nil,
        windSpeedKmh: Double? = nil,
        windGustKmh: Double? = nil,
        precipitationProbability: Double? = nil,
        cloudCoverPercent: Double? = nil
    ) {
        self.time = time
        self.temperatureC = temperatureC
        self.windSpeedKmh = windSpeedKmh
        self.windGustKmh = windGustKmh
        self.precipitationProbability = precipitationProbability
        self.cloudCoverPercent = cloudCoverPercent
    }
}

private struct OpenMeteoBOMResponse: Decodable {
    let hourly: Hourly
    let hourly_units: [String: String]?

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]?
        let windspeed_10m: [Double?]?
        let windgusts_10m: [Double?]?
        let precipitation_probability: [Double?]?
        let cloudcover: [Double?]?
    }
}

public struct OpenMeteoBOMClient {
    private let session: URLSession
    private let isoNoTz: ISO8601DateFormatter

    public init(session: URLSession = OpenMeteoBOMClient.makeDefaultSession()) {
        self.session = session
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        self.isoNoTz = f
    }

    public func fetchHourly(
        latitude: Double,
        longitude: Double,
        hours: Int = 48,
        timezone: String = "Australia/Sydney"
    ) async throws -> [OpenMeteoHourlyPoint] {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/bom")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,windspeed_10m,windgusts_10m,precipitation_probability,cloudcover"),
            URLQueryItem(name: "forecast_days", value: String(max(1, hours / 24 + 1))),
            URLQueryItem(name: "timezone", value: timezone),
        ]
        guard let url = c.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(BOMConfig.userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError, Self.shouldRetry(urlError.code) {
                try? await Task.sleep(nanoseconds: 500_000_000)
                (data, _) = try await session.data(for: request)
            } else {
                throw error
            }
        }
        let decoded = try JSONDecoder().decode(OpenMeteoBOMResponse.self, from: data)
        let count = decoded.hourly.time.count
        guard count > 0 else {
            throw OpenMeteoClientError.emptySeries
        }
        var out: [OpenMeteoHourlyPoint] = []
        out.reserveCapacity(count)
        for i in 0 ..< count {
            let t = decoded.hourly.time[i]
            let date = isoNoTz.date(from: t) ?? ISO8601DateFormatter().date(from: t + "Z")
            guard let date else { continue }
            let pp = decoded.hourly.precipitation_probability?[i].map { $0 / 100.0 }
            let cloud = decoded.hourly.cloudcover?[i]
            out.append(
                OpenMeteoHourlyPoint(
                    time: date,
                    temperatureC: decoded.hourly.temperature_2m?[i] ?? nil,
                    windSpeedKmh: decoded.hourly.windspeed_10m?[i] ?? nil,
                    windGustKmh: decoded.hourly.windgusts_10m?[i] ?? nil,
                    precipitationProbability: pp,
                    cloudCoverPercent: cloud
                )
            )
        }
        let hasSignal = out.contains {
            $0.windSpeedKmh != nil || $0.windGustKmh != nil || $0.temperatureC != nil || $0.precipitationProbability != nil
        }
        guard hasSignal else {
            throw OpenMeteoClientError.emptySeries
        }
        return out
    }

    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        return URLSession(configuration: config)
    }

    private static func shouldRetry(_ code: URLError.Code) -> Bool {
        switch code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
