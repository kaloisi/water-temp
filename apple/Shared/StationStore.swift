import Foundation

/// Persists the user's station list in the App Group container so the app and
/// the widget extension see the same stations.
enum StationStore {
    /// Must match the App Group in both targets' entitlements.
    static let appGroupID = "group.com.kaloisi.watertemp"

    static let defaultStations: [Station] = [
        Station(id: "KMAWEBST38", name: "Water Temp"),
        Station(id: "KMAWEBST37", name: "Air Temp"),
    ]

    private static let key = "stations"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> [Station] {
        guard let data = defaults.data(forKey: key),
              let stations = try? JSONDecoder().decode([Station].self, from: data)
        else {
            return defaultStations
        }
        return stations
    }

    static func save(_ stations: [Station]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: key)
    }
}
