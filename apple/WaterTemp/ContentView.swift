import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: StationListModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var newStationID = ""
    @State private var newStationName = ""
    @State private var addError: String?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.stations.isEmpty {
                        Text("No stations yet. Add one below.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.stations) { station in
                        Button {
                            openURL(station.dashboardURL)
                        } label: {
                            StationRow(station: station, reading: model.readings[station.id])
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open in Browser") { openURL(station.dashboardURL) }
                            Button("Remove", role: .destructive) { model.remove(station) }
                        }
                    }
                    .onDelete(perform: model.remove(atOffsets:))
                    .onMove(perform: model.move(fromOffsets:toOffset:))
                } header: {
                    Text("Stations")
                } footer: {
                    Text("Tap a station to open its Weather Underground page.")
                }

                Section {
                    TextField("Station ID (e.g. KMAWEBST38)", text: $newStationID)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onSubmit(addStation)
                    TextField("Name (optional)", text: $newStationName)
                        .onSubmit(addStation)
                    if let addError {
                        Text(addError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button(action: addStation) {
                        HStack {
                            Text("Add Station")
                            if isAdding {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isAdding || newStationID.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Add Station")
                } footer: {
                    Text("Find station IDs on wunderground.com/wundermap. Changes appear in your widgets automatically.")
                }
            }
            .navigationTitle("Water Temp")
            .refreshable { await model.refresh() }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .task { await model.refresh() }
        .onOpenURL { url in
            if let browserURL = DeepLink.browserURL(for: url) {
                openURL(browserURL)
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }

    private func addStation() {
        guard !isAdding else { return }
        isAdding = true
        addError = nil
        Task {
            defer { isAdding = false }
            do {
                try await model.add(id: newStationID, name: newStationName)
                newStationID = ""
                newStationName = ""
            } catch {
                addError = error.localizedDescription
            }
        }
    }
}

private struct StationRow: View {
    let station: Station
    let reading: Reading?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reading?.name ?? station.displayName)
                    .font(.headline)
                Text(station.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let reading, !reading.failed {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(reading.temperatureText + "F")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    if let observedAt = reading.observedAt {
                        Text(observedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if reading?.failed == true {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("Couldn't load this station")
            } else {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
        .environmentObject(StationListModel())
}
