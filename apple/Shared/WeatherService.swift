import Foundation

/// The subset of a weather.com PWS observation that the app uses.
struct Observation: Decodable {
    struct Imperial: Decodable {
        let temp: Double?
    }

    let stationID: String
    let neighborhood: String?
    let epoch: TimeInterval?
    let imperial: Imperial?

    var observedAt: Date? { epoch.map(Date.init(timeIntervalSince1970:)) }
}

/// The latest temperature for one station, ready for display.
struct Reading: Hashable, Identifiable {
    let stationID: String
    var name: String
    var temperature: Double?
    var observedAt: Date?
    var failed: Bool

    var id: String { stationID }

    var temperatureText: String {
        guard let temperature else { return "--" }
        return String(format: "%.1f°", temperature)
    }

    init(station: Station, observation: Observation) {
        stationID = station.id
        name = station.name.flatMap { $0.isEmpty ? nil : $0 } ?? observation.neighborhood ?? station.id
        temperature = observation.imperial?.temp
        observedAt = observation.observedAt
        failed = false
    }

    init(failedStation station: Station) {
        stationID = station.id
        name = station.displayName
        temperature = nil
        observedAt = nil
        failed = true
    }

    init(stationID: String, name: String, temperature: Double?, observedAt: Date? = nil) {
        self.stationID = stationID
        self.name = name
        self.temperature = temperature
        self.observedAt = observedAt
        self.failed = false
    }
}

enum WeatherService {
    /// Same public key the web app uses; native clients don't need the CORS proxy.
    static let apiKey = "76ac86a6e10f44d6ac86a6e10ff4d6e6"

    enum ServiceError: LocalizedError {
        case stationNotFound(String)
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .stationNotFound(let id): "No current data found for station \(id)."
            case .badResponse(let status): "The weather service returned an error (\(status))."
            }
        }
    }

    static func dashboardURL(for stationID: String) -> URL {
        URL(string: "https://www.wunderground.com/dashboard/pws/\(stationID)")!
    }

    static func currentObservation(for stationID: String) async throws -> Observation {
        var components = URLComponents(string: "https://api.weather.com/v2/pws/observations/current")!
        components.queryItems = [
            URLQueryItem(name: "stationId", value: stationID),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "units", value: "e"),
            URLQueryItem(name: "numericPrecision", value: "decimal"),
            URLQueryItem(name: "apiKey", value: apiKey),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        // The API answers 204 No Content for unknown or offline stations.
        if status == 204 || status == 404 {
            throw ServiceError.stationNotFound(stationID)
        }
        guard (200..<300).contains(status) else {
            throw ServiceError.badResponse(status)
        }

        struct Response: Decodable { let observations: [Observation] }
        guard let observation = try JSONDecoder().decode(Response.self, from: data).observations.first else {
            throw ServiceError.stationNotFound(stationID)
        }
        return observation
    }

    /// Fetches all stations concurrently, preserving the input order. Stations
    /// that fail to load come back as `failed` readings rather than throwing.
    static func readings(for stations: [Station]) async -> [Reading] {
        await withTaskGroup(of: (Int, Reading).self) { group in
            for (index, station) in stations.enumerated() {
                group.addTask {
                    do {
                        let observation = try await currentObservation(for: station.id)
                        return (index, Reading(station: station, observation: observation))
                    } catch {
                        return (index, Reading(failedStation: station))
                    }
                }
            }

            var results = [Reading?](repeating: nil, count: stations.count)
            for await (index, reading) in group {
                results[index] = reading
            }
            return results.compactMap { $0 }
        }
    }
}
