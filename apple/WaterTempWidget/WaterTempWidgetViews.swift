import SwiftUI
import WidgetKit

struct WaterTempWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TemperatureEntry

    var body: some View {
        #if os(iOS)
        if family == .accessoryInline {
            InlineAccessoryView(readings: entry.readings)
        } else if family == .accessoryRectangular {
            RectangularAccessoryView(readings: entry.readings)
        } else {
            TileView(entry: entry, family: family)
        }
        #else
        TileView(entry: entry, family: family)
        #endif
    }
}

/// Home screen / desktop widget: a list of stations, each a tap target that
/// opens the station's Weather Underground page.
private struct TileView: View {
    let entry: TemperatureEntry
    let family: WidgetFamily

    private var maxRows: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        case .systemLarge: 8
        default: 12
        }
    }

    private var visible: [Reading] { Array(entry.readings.prefix(maxRows)) }
    private var isSmall: Bool { family == .systemSmall }

    /// Small widgets are a single tap target, so they open the station page
    /// directly when there's one station, or the app's list otherwise.
    private var smallWidgetURL: URL? {
        guard isSmall else { return nil }
        if entry.readings.count == 1, let only = entry.readings.first {
            return DeepLink.url(for: only.stationID)
        }
        return DeepLink.stationList
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 4 : 6) {
            HStack(spacing: 4) {
                Image(systemName: "thermometer.medium")
                Text(entry.date, style: .time)
                Spacer(minLength: 0)
                if entry.readings.count > visible.count {
                    Text("+\(entry.readings.count - visible.count)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if visible.isEmpty {
                Spacer(minLength: 0)
                Text("No stations. Open Water Temp to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(visible) { reading in
                Link(destination: DeepLink.url(for: reading.stationID)) {
                    ReadingRow(reading: reading, compact: isSmall)
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(smallWidgetURL)
    }
}

private struct ReadingRow: View {
    let reading: Reading
    let compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(reading.name)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !compact {
                    Text(reading.stationID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if reading.failed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                // Small widgets are narrow, so °C goes under °F; wider
                // widgets keep each row to one line by putting it alongside.
                let layout = compact
                    ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
                layout {
                    Text(reading.fahrenheitText)
                        .font(compact ? .title3 : .title2)
                        .fontWeight(.semibold)
                    Text(reading.celsiusText)
                        .font(compact ? .caption2 : .subheadline)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .contentShape(Rectangle())
    }
}

#if os(iOS)
private struct RectangularAccessoryView: View {
    let readings: [Reading]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(readings.prefix(3)) { reading in
                HStack {
                    Text(reading.name).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(reading.failed ? "--" : reading.temperatureText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .widgetURL(readings.count == 1 ? DeepLink.url(for: readings[0].stationID) : DeepLink.stationList)
    }
}

private struct InlineAccessoryView: View {
    let readings: [Reading]

    var body: some View {
        if let first = readings.first {
            Text("\(Image(systemName: "thermometer.medium")) \(first.name) \(first.failed ? "--" : first.temperatureText)")
                .widgetURL(DeepLink.url(for: first.stationID))
        } else {
            Text("No stations")
        }
    }
}
#endif
