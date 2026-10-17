#if os(macOS)
import SwiftUI

/// The macOS station manager: a standard table with +/− buttons beneath it,
/// click-to-edit Name and Station ID cells, a context menu, Delete-key
/// removal, drag-to-reorder and an Add sheet.
struct StationTableView: View {
    @EnvironmentObject private var model: StationListModel

    @State private var selection = Set<Station.ID>()
    @State private var editError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            table
            Divider()
            bottomBar
        }
        .navigationTitle("Water Temp")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh temperatures")
                .disabled(model.isRefreshing)
            }
        }
        .sheet(isPresented: $model.isPresentingAddStation) {
            AddStationSheet()
        }
        .alert(
            "Couldn't Change Station",
            isPresented: Binding(get: { editError != nil }, set: { if !$0 { editError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(editError ?? "")
        }
        .frame(minWidth: 520, minHeight: 300)
    }

    private var table: some View {
        Table(of: Station.self, selection: $selection) {
            TableColumn("Name") { station in
                EditableTextCell(
                    value: station.name ?? "",
                    prompt: model.readings[station.id]?.name ?? station.id
                ) { newName in
                    model.rename(station.id, to: newName)
                    return true
                }
            }
            .width(min: 120, ideal: 180)

            TableColumn("Station ID") { station in
                EditableTextCell(value: station.id, prompt: "Station ID") { newID in
                    await changeID(of: station.id, to: newID)
                }
            }
            .width(min: 90, ideal: 110)

            TableColumn("°F") { station in
                TemperatureCell(reading: model.readings[station.id], unit: \.fahrenheitText)
            }
            .width(min: 60, ideal: 70)
            .alignment(.trailing)

            TableColumn("°C") { station in
                TemperatureCell(reading: model.readings[station.id], unit: \.celsiusText)
            }
            .width(min: 60, ideal: 70)
            .alignment(.trailing)

            TableColumn("Updated") { station in
                if let observedAt = model.readings[station.id]?.observedAt {
                    Text(observedAt, style: .time)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 70, ideal: 80)
        } rows: {
            ForEach(model.stations) { station in
                TableRow(station)
                    .draggable(station.id)
                    .dropDestination(for: String.self) { ids in
                        model.move(ids: ids, onto: station.id)
                    }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Station.ID.self) { ids in
            if ids.isEmpty {
                Button("Add Station…") { model.isPresentingAddStation = true }
            } else {
                Button(ids.count == 1 ? "Remove Station" : "Remove \(ids.count) Stations") {
                    remove(ids)
                }
            }
        }
        .onDeleteCommand { remove(selection) }
        .overlay {
            if model.stations.isEmpty {
                ContentUnavailableView {
                    Label("No Stations", systemImage: "thermometer.medium")
                } description: {
                    Text("Click + to add a Weather Underground station.")
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button {
                model.isPresentingAddStation = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 20)
            }
            .help("Add a station")

            Divider()
                .frame(height: 16)

            Button {
                remove(selection)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 20)
            }
            .help("Remove the selected stations")
            .disabled(selection.isEmpty)

            Spacer()

            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }
        }
        .buttonStyle(.borderless)
        .padding(4)
        .background(.bar)
    }

    private var subtitle: String {
        switch model.stations.count {
        case 0: "No stations"
        case 1: "1 station"
        default: "\(model.stations.count) stations"
        }
    }

    /// Returns whether the change was saved; on failure the cell reverts.
    private func changeID(of stationID: Station.ID, to newID: String) async -> Bool {
        do {
            try await model.changeID(of: stationID, to: newID)
            if selection.remove(stationID) != nil, let id = StationID.normalize(newID) {
                selection.insert(id)
            }
            return true
        } catch {
            editError = error.localizedDescription
            return false
        }
    }

    private func remove(_ ids: Set<Station.ID>) {
        guard !ids.isEmpty else { return }
        model.remove(ids: ids)
        selection.subtract(ids)
    }
}

/// A table cell that edits in place when clicked. Return or clicking away
/// saves, Escape cancels.
private struct EditableTextCell: View {
    let value: String
    let prompt: String
    /// Saves the edited text; returns `false` to revert the cell.
    let commit: (String) async -> Bool

    @State private var text = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .disabled(isSaving)
            .onAppear { text = value }
            .onChange(of: value) { _, newValue in
                if !isFocused { text = newValue }
            }
            .onSubmit { isFocused = false }
            .onExitCommand {
                text = value
                isFocused = false
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { save() }
            }
    }

    private func save() {
        guard text != value, !isSaving else { return }
        let original = value
        isSaving = true
        Task {
            if !(await commit(text)) {
                text = original
            }
            isSaving = false
        }
    }
}

private struct TemperatureCell: View {
    let reading: Reading?
    let unit: KeyPath<Reading, String>

    var body: some View {
        if let reading, !reading.failed {
            Text(reading[keyPath: unit])
                .monospacedDigit()
        } else if reading?.failed == true {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .help("Couldn't load this station")
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }
}

/// A standard macOS sheet for adding a station, validated against the
/// weather service before it's saved.
private struct AddStationSheet: View {
    @EnvironmentObject private var model: StationListModel
    @Environment(\.dismiss) private var dismiss

    @State private var stationID = ""
    @State private var name = ""
    @State private var error: String?
    @State private var isAdding = false

    private var canAdd: Bool {
        !isAdding && !stationID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Station")
                .font(.headline)

            Form {
                TextField("Station ID:", text: $stationID, prompt: Text("KMAWEBST38"))
                TextField("Name:", text: $name, prompt: Text("Optional"))
            }
            .disabled(isAdding)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Find station IDs on wunderground.com/wundermap.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking station…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func add() {
        guard canAdd else { return }
        isAdding = true
        error = nil
        Task {
            defer { isAdding = false }
            do {
                try await model.add(id: stationID, name: name)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
#endif
