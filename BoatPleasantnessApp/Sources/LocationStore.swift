import Foundation
import WeatherCore

struct QueenslandLocationPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double

    var storedLocation: StoredLocation {
        StoredLocation(
            name: name,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: "Australia/Brisbane"
        )
    }

    static let all: [QueenslandLocationPreset] = [
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
