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

struct Provider: AppIntentTimelineProvider {
    /// How often WidgetKit is asked to refresh. The system may stretch this.
    private let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> TemperatureEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> TemperatureEntry {
        if context.isPreview {
            return .placeholder
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<TemperatureEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(refreshInterval)))
    }

    private func entry(for configuration: ConfigurationAppIntent) async -> TemperatureEntry {
        let readings = await WeatherService.readings(for: configuration.resolvedStations())
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
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
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
