import SwiftUI
import WidgetKit

struct TemperatureEntry: TimelineEntry {
    let date: Date
    let readings: [Reading]

    static let placeholder = TemperatureEntry(
        date: .now,
        readings: [
            Reading(stationID: "KMAWEBST38", name: "Water Temp", temperature: 68.4, observedAt: .now),
            Reading(stationID: "KMAWEBST37", name: "Air Temp", temperature: 74.1, observedAt: .now),
        ]
    )
}

/// Always shows the station list saved by the Water Temp app, so every widget
/// matches the app.
struct Provider: TimelineProvider {
    /// How often WidgetKit is asked to refresh. The system may stretch this.
    private let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> TemperatureEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TemperatureEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TemperatureEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(refreshInterval))))
        }
    }

    private func currentEntry() async -> TemperatureEntry {
        let readings = await WeatherService.readings(for: StationStore.load())
        return TemperatureEntry(date: .now, readings: readings)
    }
}

struct WaterTempWidget: Widget {
    let kind = "WaterTempWidget"

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WaterTempWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Temperature")
        .description("The latest temperature from your weather stations. Tap a station to open its page.")
        .supportedFamilies(Self.families)
    }
}

#Preview(as: .systemSmall) {
    WaterTempWidget()
} timeline: {
    TemperatureEntry.placeholder
}

#Preview(as: .systemMedium) {
    WaterTempWidget()
} timeline: {
    TemperatureEntry.placeholder
}
