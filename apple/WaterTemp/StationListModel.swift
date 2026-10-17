import Foundation
import WidgetKit

@MainActor
final class StationListModel: ObservableObject {
    enum StationError: LocalizedError {
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
    /// Drives the macOS Add Station sheet, so the File menu command can open it.
    @Published var isPresentingAddStation = false

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let latest = await WeatherService.readings(for: stations)
        readings = Dictionary(latest.map { ($0.stationID, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Adds a station after confirming the weather service knows about it.
    func add(id rawID: String, name rawName: String) async throws {
        guard let id = StationID.normalize(rawID) else { throw StationError.invalidID }
        guard !stations.contains(where: { $0.id == id }) else { throw StationError.duplicate(id) }

        let observation = try await WeatherService.currentObservation(for: id)
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let station = Station(id: id, name: name.isEmpty ? observation.neighborhood : name)

        stations.append(station)
        readings[id] = Reading(station: station, observation: observation)
        persist()
    }

    /// Sets a station's friendly name. An empty name falls back to the
    /// station's neighborhood or ID.
    func rename(_ stationID: Station.ID, to rawName: String) {
        guard let index = stations.firstIndex(where: { $0.id == stationID }) else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        stations[index].name = name.isEmpty ? nil : name
        persist()
        if name.isEmpty {
            Task { await refresh() }
        } else {
            readings[stationID]?.name = name
        }
    }

    /// Points an existing entry at a different station, after confirming the
    /// weather service knows about it. Keeps the entry's name and position.
    func changeID(of stationID: Station.ID, to rawID: String) async throws {
        guard let id = StationID.normalize(rawID) else { throw StationError.invalidID }
        guard id != stationID else { return }
        guard !stations.contains(where: { $0.id == id }) else { throw StationError.duplicate(id) }

        let observation = try await WeatherService.currentObservation(for: id)
        guard let index = stations.firstIndex(where: { $0.id == stationID }) else { return }
        stations[index].id = id
        readings[stationID] = nil
        readings[id] = Reading(station: stations[index], observation: observation)
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

    func remove(ids: Set<Station.ID>) {
        stations.removeAll { ids.contains($0.id) }
        for id in ids {
            readings[id] = nil
        }
        persist()
    }

    /// Moves the given stations next to `targetID`: after it when dragging
    /// downward, before it when dragging upward.
    func move(ids: [Station.ID], onto targetID: Station.ID) {
        guard !ids.contains(targetID),
              let sourceIndex = stations.firstIndex(where: { ids.contains($0.id) }),
              let targetIndex = stations.firstIndex(where: { $0.id == targetID })
        else { return }

        let moving = stations.filter { ids.contains($0.id) }
        var remaining = stations.filter { !ids.contains($0.id) }
        guard let anchor = remaining.firstIndex(where: { $0.id == targetID }) else { return }
        remaining.insert(contentsOf: moving, at: sourceIndex < targetIndex ? anchor + 1 : anchor)
        stations = remaining
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
