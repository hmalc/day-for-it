import Foundation
import WeatherCore

enum LocationCoverageLevel: String, Equatable {
    case fullQueensland
    case officialForecastOnly

    var label: String {
        switch self {
        case .fullQueensland:
            return "Forecasts, tides, and waves"
        case .officialForecastOnly:
            return "Official forecast only"
        }
    }

    var detail: String {
        switch self {
        case .fullQueensland:
            return "BOM forecasts and observations, Queensland tide predictions, and Queensland wave observations."
        case .officialForecastOnly:
            return "BOM coastal forecast, observations, and marine warnings. Tide and live wave feeds stay unavailable until an official local source is wired in."
        }
    }
}

struct LocationPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    let coverage: LocationCoverageLevel
    let feed: MarineFeedConfig?

    init(
        id: String,
        name: String,
        region: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String = "Australia/Brisbane",
        coverage: LocationCoverageLevel = .fullQueensland,
        feed: MarineFeedConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.coverage = coverage
        self.feed = feed
    }

    var storedLocation: StoredLocation {
        StoredLocation(
            name: name,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZoneID
        )
    }

    static let all: [LocationPreset] = queensland + forecastOnly

    static let queensland: [LocationPreset] = [
        .init(id: "cowley-beach", name: "Cowley Beach", region: "Cassowary Coast", latitude: -17.679, longitude: 146.112),
        .init(id: "cairns", name: "Cairns", region: "Far North Queensland", latitude: -16.918, longitude: 145.778),
        .init(id: "port-douglas", name: "Port Douglas", region: "Far North Queensland", latitude: -16.484, longitude: 145.467),
        .init(id: "townsville", name: "Townsville", region: "North Queensland", latitude: -19.259, longitude: 146.817),
        .init(id: "airlie-beach", name: "Airlie Beach", region: "Whitsundays", latitude: -20.268, longitude: 148.719),
        .init(id: "mackay", name: "Mackay", region: "Mackay Coast", latitude: -21.142, longitude: 149.186),
        .init(id: "yeppoon", name: "Yeppoon", region: "Capricorn Coast", latitude: -23.127, longitude: 150.744),
        .init(id: "gladstone", name: "Gladstone", region: "Central Queensland", latitude: -23.842, longitude: 151.256),
        .init(id: "bundaberg", name: "Bundaberg", region: "Wide Bay", latitude: -24.867, longitude: 152.348),
        .init(id: "hervey-bay", name: "Hervey Bay", region: "Fraser Coast", latitude: -25.288, longitude: 152.839),
        .init(id: "mooloolaba", name: "Mooloolaba", region: "Sunshine Coast", latitude: -26.681, longitude: 153.121),
        .init(id: "brisbane", name: "Brisbane", region: "Moreton Bay", latitude: -27.470, longitude: 153.030),
        .init(id: "gold-coast", name: "Gold Coast Seaway", region: "Gold Coast", latitude: -27.933, longitude: 153.426)
    ]

    static let forecastOnly: [LocationPreset] = [
        .init(
            id: "byron-bay",
            name: "Byron Bay",
            region: "NSW North Coast",
            latitude: -28.647,
            longitude: 153.602,
            timeZoneID: "Australia/Sydney",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDN11001",
                observationProductID: "IDN60801",
                observationStationWMO: 94599,
                marineWarningRSSPath: "/fwo/IDZ00068.warnings_marine_nsw.xml",
                preferredCoastalAAC: "NSW_MW008"
            )
        ),
        .init(
            id: "sydney-harbour",
            name: "Sydney Harbour",
            region: "Sydney Coast",
            latitude: -33.843,
            longitude: 151.255,
            timeZoneID: "Australia/Sydney",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDN11001",
                observationProductID: "IDN60801",
                observationStationWMO: 95766,
                marineWarningRSSPath: "/fwo/IDZ00068.warnings_marine_nsw.xml",
                preferredCoastalAAC: "NSW_MW004"
            )
        ),
        .init(
            id: "melbourne-bay",
            name: "Melbourne Bay",
            region: "Central Victoria",
            latitude: -37.866,
            longitude: 144.976,
            timeZoneID: "Australia/Melbourne",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDV10200",
                observationProductID: "IDV60801",
                observationStationWMO: 94892,
                marineWarningRSSPath: "/fwo/IDZ00073.warnings_marine_vic.xml",
                preferredCoastalAAC: "VIC_MW002"
            )
        ),
        .init(
            id: "adelaide-gulf",
            name: "Adelaide Gulf",
            region: "Gulf St Vincent",
            latitude: -34.844,
            longitude: 138.475,
            timeZoneID: "Australia/Adelaide",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDS11072",
                observationProductID: "IDS60801",
                observationStationWMO: 94648,
                marineWarningRSSPath: "/fwo/IDZ00071.warnings_marine_sa.xml",
                preferredCoastalAAC: "SA_MW006"
            )
        ),
        .init(
            id: "rottnest-fremantle",
            name: "Rottnest / Fremantle",
            region: "Perth Coast",
            latitude: -32.006,
            longitude: 115.512,
            timeZoneID: "Australia/Perth",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDW11160",
                observationProductID: "IDW60801",
                observationStationWMO: 94602,
                marineWarningRSSPath: "/fwo/IDZ00074.warnings_marine_wa.xml",
                preferredCoastalAAC: "WA_MW009"
            )
        ),
        .init(
            id: "hobart-estuary",
            name: "Hobart Estuary",
            region: "South East Tasmania",
            latitude: -42.882,
            longitude: 147.331,
            timeZoneID: "Australia/Hobart",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDT12329",
                observationProductID: "IDT60801",
                observationStationWMO: 94970,
                marineWarningRSSPath: "/fwo/IDZ00072.warnings_marine_tas.xml",
                preferredCoastalAAC: "TAS_MW006"
            )
        ),
        .init(
            id: "darwin-harbour",
            name: "Darwin Harbour",
            region: "Northern Territory",
            latitude: -12.467,
            longitude: 130.845,
            timeZoneID: "Australia/Darwin",
            coverage: .officialForecastOnly,
            feed: MarineFeedConfig(
                coastalProductID: "IDD11030",
                observationProductID: "IDD60801",
                observationStationWMO: 94120,
                marineWarningRSSPath: "/fwo/IDZ00069.warnings_marine_nt.xml",
                preferredCoastalAAC: "NT_MW007"
            )
        )
    ]

    static func nearestForecastOnly(to location: StoredLocation, maximumDistanceKm: Double = 180) -> LocationPreset? {
        nearestForecastOnly(latitude: location.latitude, longitude: location.longitude, maximumDistanceKm: maximumDistanceKm)
    }

    static func nearestForecastOnly(latitude: Double, longitude: Double, maximumDistanceKm: Double = 180) -> LocationPreset? {
        let matches = forecastOnly.map { preset in
            (preset: preset, distanceKm: distanceKm(fromLat: latitude, fromLon: longitude, toLat: preset.latitude, toLon: preset.longitude))
        }
        guard let nearest = matches.min(by: { $0.distanceKm < $1.distanceKm }), nearest.distanceKm <= maximumDistanceKm else {
            return nil
        }
        return nearest.preset
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

struct StoredLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String

    var marineLocation: MarineLocation {
        MarineLocation(name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID)
    }
}

struct LocationStore {
    private let defaults: UserDefaults
    private let key = "saved_location_override_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredLocation? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredLocation.self, from: data)
    }

    func save(_ location: StoredLocation?) {
        guard let location else {
            defaults.removeObject(forKey: key)
            return
        }
        let data = try? JSONEncoder().encode(location)
        defaults.set(data, forKey: key)
    }
}
