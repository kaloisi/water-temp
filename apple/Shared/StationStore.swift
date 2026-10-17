import Foundation
import os

/// Persists the user's station list in the App Group container so the app and
/// the widget extension see the same stations.
enum StationStore {
    /// Comes from the `APP_GROUP_ID` build setting via each target's Info.plist,
    /// the same value written into both targets' entitlements. iOS uses
    /// `group.com.kaloisi.watertemp`; macOS uses the team-prefixed form, which
    /// macOS allows without the group being listed in the provisioning profile.
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        ?? "group.com.kaloisi.watertemp"

    static let defaultStations: [Station] = [
        Station(id: "KMAWEBST38", name: "Water Temp"),
        Station(id: "KMAWEBST37", name: "Air Temp"),
    ]

    private static let key = "stations"

    private static let logger = Logger(subsystem: "com.kaloisi.WaterTemp", category: "StationStore")

    /// The shared App Group defaults. If the target isn't signed with the App
    /// Group entitlement, the app and widget would each get a private copy and
    /// drift apart, so that misconfiguration is logged loudly.
    private static let defaults: UserDefaults = {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) == nil {
            logger.fault("App Group \(appGroupID, privacy: .public) is unavailable; the app and widget will not share stations. Check Signing & Capabilities for both targets.")
        }
        return UserDefaults(suiteName: appGroupID) ?? .standard
    }()

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
