import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var selectedPresetID = QueenslandLocationPreset.all.first?.id ?? ""
    @State private var presetPickerIsReady = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    if let override = model.savedOverride {
                        LabeledContent("Using", value: override.name)
                        LabeledContent("Coordinates", value: coordinateText(latitude: override.latitude, longitude: override.longitude))
                        Button("Use Cowley Beach default", role: .destructive) {
                            model.clearLocationOverride()
                        }
                    } else {
                        LabeledContent("Using", value: model.effectiveLocation().name)
                        Text("Choose a Queensland boating area or use your current location.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Queensland boating area") {
                    Picker("Area", selection: $selectedPresetID) {
                        ForEach(model.availableQueenslandLocations) { preset in
                            Text("\(preset.name) · \(preset.region)").tag(preset.id)
                        }
                    }
                    .onChange(of: selectedPresetID) { _, newValue in
                        guard presetPickerIsReady else { return }
                        guard let preset = model.availableQueenslandLocations.first(where: { $0.id == newValue }) else { return }
                        model.saveLocationPreset(preset)
                    }

                    Text("Changing this refreshes the marine forecast and nearest tide station.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Current location") {
                    Button {
                        model.useCurrentLocation()
                    } label: {
                        Label("Use my current Queensland location", systemImage: "location")
                    }

                    if let coordinate = model.locationManager.currentCoordinate {
                        Text(coordinateText(latitude: coordinate.latitude, longitude: coordinate.longitude))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Location permission may be requested. Forecasts stay on Queensland marine zones.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Manual Queensland location") {
                    TextField("Name", text: $name)
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                    Button {
                        guard let lat = Double(latitude), let lon = Double(longitude), !name.isEmpty else { return }
                        model.saveLocationOverride(name: name, latitude: lat, longitude: lon)
                    } label: {
                        Label("Save manual location", systemImage: "checkmark.circle")
                    }
                    .disabled(!manualLocationIsValid)
                }

                Section("Data") {
                    Button("Refresh now") {
                        Task { await model.refresh() }
                    }
                    Text(model.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                presetPickerIsReady = false
                selectedPresetID = matchingPresetID() ?? selectedPresetID
                Task { @MainActor in
                    await Task.yield()
                    presetPickerIsReady = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var manualLocationIsValid: Bool {
        guard let lat = Double(latitude), let lon = Double(longitude), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return (-29.5 ... -9.0).contains(lat) && (137.5 ... 154.5).contains(lon)
    }

    private func matchingPresetID() -> String? {
        guard let saved = model.savedOverride else { return QueenslandLocationPreset.all.first?.id }
        return model.availableQueenslandLocations.min { lhs, rhs in
            let left = hypot(lhs.latitude - saved.latitude, lhs.longitude - saved.longitude)
            let right = hypot(rhs.latitude - saved.latitude, rhs.longitude - saved.longitude)
            return left < right
        }?.id
    }

    private func coordinateText(latitude: Double, longitude: Double) -> String {
        String(format: "%.3f, %.3f", latitude, longitude)
    }
}
