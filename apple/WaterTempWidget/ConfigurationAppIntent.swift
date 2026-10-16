import AppIntents
import WidgetKit

/// Lets each widget instance pick its own stations via "Edit Widget".
/// Leaving the list empty shows the stations saved in the Water Temp app.
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Stations"
    static let description = IntentDescription(
        "Choose which weather stations to show. Leave empty to use the stations from the Water Temp app."
    )

    @Parameter(title: "Station IDs", default: [])
    var stationIDs: [String]

    init() {}

    init(stationIDs: [String]) {
        self.stationIDs = stationIDs
    }

    /// The stations this widget should display, in order and without duplicates.
    func resolvedStations() -> [Station] {
        let saved = StationStore.load()
        let ids = stationIDs.compactMap(StationID.normalize)
        guard !ids.isEmpty else { return saved }

        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return saved.first { $0.id == id } ?? Station(id: id)
        }
    }
}
