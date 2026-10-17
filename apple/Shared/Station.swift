import Foundation

/// A Weather Underground personal weather station the user wants to track.
struct Station: Codable, Hashable, Identifiable {
    /// The PWS station ID, e.g. `KMAWEBST38`.
    var id: String
    /// Optional friendly name shown instead of the raw ID.
    var name: String?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return id
    }

    var dashboardURL: URL { WeatherService.dashboardURL(for: id) }
}

enum StationID {
    /// Trims and upper-cases a user-entered station ID. Returns `nil` if it is
    /// empty or contains anything other than ASCII letters and digits.
    static func normalize(_ raw: String) -> String? {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !id.isEmpty, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            return nil
        }
        return id
    }
}
