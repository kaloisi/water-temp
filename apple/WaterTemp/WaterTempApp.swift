import SwiftUI

@main
struct WaterTempApp: App {
    @StateObject private var model = StationListModel()

    var body: some Scene {
        #if os(macOS)
        // A single window, so widget taps reuse it instead of opening new ones.
        Window("Water Temp", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        #endif
    }
}
