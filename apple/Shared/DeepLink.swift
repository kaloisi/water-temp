import Foundation

/// Widget taps are delivered to the containing app, which then opens the
/// station's Weather Underground page in the default browser.
enum DeepLink {
    static let scheme = "watertemp"

    /// Opens the app's station list.
    static let stationList = URL(string: "\(scheme)://stations")!

    static func url(for stationID: String) -> URL {
        URL(string: "\(scheme)://station/\(stationID)")!
    }

    /// The web page to open for a URL the app was launched with, if any.
    static func browserURL(for url: URL) -> URL? {
        if url.scheme == "https" || url.scheme == "http" {
            return url
        }
        guard url.scheme == scheme, url.host == "station",
              let id = StationID.normalize(url.lastPathComponent)
        else {
            return nil
        }
        return WeatherService.dashboardURL(for: id)
    }
}
