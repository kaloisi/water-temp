import Foundation
import WidgetKit

@MainActor
final class StationListModel: ObservableObject {
    enum AddError: LocalizedError {
        case invalidID
        case duplicate(String)

        var errorDescription: String? {
            switch self {
            case .invalidID: "Station IDs contain only letters and numbers, e.g. KMAWEBST38."
            case .duplicate(let id): "\(id) is already in your list."
            }
        }
    }

    @Published private(set) var stations: [Station] = StationStore.load()
    @Published private(set) var readings: [String: Reading] = [:]
    @Published private(set) var isRefreshing = false

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let latest = await WeatherService.readings(for: stations)
        readings = Dictionary(latest.map { ($0.stationID, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Adds a station after confirming the weather service knows about it.
    func add(id rawID: String, name rawName: String) async throws {
        guard let id = StationID.normalize(rawID) else { throw AddError.invalidID }
        guard !stations.contains(where: { $0.id == id }) else { throw AddError.duplicate(id) }

        let observation = try await WeatherService.currentObservation(for: id)
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let station = Station(id: id, name: name.isEmpty ? observation.neighborhood : name)

        stations.append(station)
        readings[id] = Reading(station: station, observation: observation)
        persist()
    }

    func remove(_ station: Station) {
        stations.removeAll { $0.id == station.id }
        readings[station.id] = nil
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets {
            readings[stations[index].id] = nil
        }
        stations.remove(atOffsets: offsets)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        stations.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        StationStore.save(stations)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
