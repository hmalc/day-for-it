import Foundation
import WeatherCore

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
