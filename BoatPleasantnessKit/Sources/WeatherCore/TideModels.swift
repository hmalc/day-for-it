import Foundation

public struct TideDaySummary: Sendable, Equatable {
    /// 0...1 suitability where higher is generally better for casual boating windows.
    public var suitability: Double
    public var summary: String
}

public enum TideDataSource: String, Codable, Sendable {
    case authoritative
    case derived
}

public enum TideExtremaKind: String, Codable, Sendable {
    case high
    case low
}

public struct TideEventPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var time: Date
    public var kind: TideExtremaKind
    public var heightMeters: Double?
    public var source: TideDataSource

    public init(
        id: UUID = UUID(),
        time: Date,
        kind: TideExtremaKind,
        heightMeters: Double?,
        source: TideDataSource
    ) {
        self.id = id
        self.time = time
        self.kind = kind
        self.heightMeters = heightMeters
        self.source = source
    }
}

public struct TideSamplePoint: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var time: Date
    public var heightMeters: Double
    public var source: TideDataSource

    public init(id: UUID = UUID(), time: Date, heightMeters: Double, source: TideDataSource) {
        self.id = id
        self.time = time
        self.heightMeters = heightMeters
        self.source = source
    }
}

public struct TideDayForecast: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { dayStart }
    public var dayStart: Date
    public var events: [TideEventPoint]
    public var samples: [TideSamplePoint]

    public init(dayStart: Date, events: [TideEventPoint], samples: [TideSamplePoint]) {
        self.dayStart = dayStart
        self.events = events
        self.samples = samples
    }
}

public struct TideForecast: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var provider: String
    public var locationName: String
    public var stationName: String?
    public var stationDistanceKm: Double?
    public var days: [TideDayForecast]

    public init(
        generatedAt: Date,
        provider: String,
        locationName: String,
        stationName: String? = nil,
        stationDistanceKm: Double? = nil,
        days: [TideDayForecast]
    ) {
        self.generatedAt = generatedAt
        self.provider = provider
        self.locationName = locationName
        self.stationName = stationName
        self.stationDistanceKm = stationDistanceKm
        self.days = days
    }
}

public enum TideDataProviderError: Error {
    case unavailable
}

public protocol TideDataProvider {
    func fetchTideForecast(
        location: MarineLocation,
        start: Date,
        days: Int,
        sampleIntervalMinutes: Int?
    ) async throws -> TideForecast
}

public enum TideInterpolation {
    /// Reliability-first interpolation:
    /// - Anchor authoritative extrema times exactly
    /// - Use half-cosine easing between extrema
    /// - Mark all generated values as `.derived`
    public static func buildDerivedSamples(
        from events: [TideEventPoint],
        stepMinutes: Int
    ) -> [TideSamplePoint] {
        guard events.count >= 2 else { return [] }
        let sorted = events.sorted { $0.time < $1.time }
        var out: [TideSamplePoint] = []
        let step = Double(max(1, stepMinutes) * 60)

        for (lhs, rhs) in zip(sorted, sorted.dropFirst()) {
            guard let h0 = lhs.heightMeters, let h1 = rhs.heightMeters else { continue }
            let t0 = lhs.time.timeIntervalSinceReferenceDate
            let t1 = rhs.time.timeIntervalSinceReferenceDate
            guard t1 > t0 else { continue }
            var t = t0
            while t < t1 {
                let phase = max(0, min(1, (t - t0) / (t1 - t0)))
                let eased = 0.5 - 0.5 * cos(.pi * phase)
                let h = h0 + (h1 - h0) * eased
                out.append(TideSamplePoint(
                    time: Date(timeIntervalSinceReferenceDate: t),
                    heightMeters: h,
                    source: .derived
                ))
                t += step
            }
        }

        if let last = sorted.last, let h = last.heightMeters {
            out.append(TideSamplePoint(time: last.time, heightMeters: h, source: .derived))
        }
        return out
    }
}
