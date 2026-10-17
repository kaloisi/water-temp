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
        .defaultSize(width: 600, height: 360)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Station…") { model.isPresentingAddStation = true }
                    .keyboardShortcut("n")
            }
            CommandGroup(before: .toolbar) {
                Button("Refresh") { Task { await model.refresh() } }
                    .keyboardShortcut("r")
                    .disabled(model.isRefreshing)
                Divider()
            }
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        #endif
    }
}
