import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var selectedPresetID = LocationPreset.all.first?.id ?? ""
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
                        Text("Choose a supported Australian boating area or use your current location.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Boating area") {
                    Picker("Area", selection: $selectedPresetID) {
                        ForEach(model.availableLocationPresets) { preset in
                            Text("\(preset.name) · \(preset.region)").tag(preset.id)
                        }
                    }
                    .onChange(of: selectedPresetID) { _, newValue in
                        guard presetPickerIsReady else { return }
                        guard let preset = model.availableLocationPresets.first(where: { $0.id == newValue }) else { return }
                        model.saveLocationPreset(preset)
                    }

                    if let selectedPreset {
                        LabeledContent("Coverage", value: selectedPreset.coverage.label)
                        Text(selectedPreset.coverage.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Changing this refreshes the marine forecast and local data sources where available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Current location") {
                    Button {
                        model.useCurrentLocation()
                    } label: {
                        Label("Use my current coastal location", systemImage: "location")
                    }

                    if let coordinate = model.locationManager.currentCoordinate {
                        Text(coordinateText(latitude: coordinate.latitude, longitude: coordinate.longitude))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Location permission may be requested. Current-location support is limited to Queensland and the listed forecast-only coastal areas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Manual coastal location") {
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
                    Text("Refresh downloads the latest available official marine forecast, warning, and observation data. Queensland areas also use official tide predictions and wave observations. The Week tab separately scans the Day For It backend for weather opportunity recommendations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Safety") {
                    Text(model.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Do not rely on Day For It as your only source for boating, navigation, weather warning, or emergency decisions. Check official forecasts, warnings, tide tables, local signage, and current conditions before heading out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    LabeledContent("Accounts", value: "None")
                    LabeledContent("Tracking", value: "None")
                    LabeledContent("Analytics", value: "None")
                    Text("Current location is only requested when you tap the current-location button. A selected manual, preset, or current-location coordinate is stored on this device as an app preference and can be replaced by choosing another area or returning to the default.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Weather opportunity scans send the selected coordinate, selected interests, and an anonymous on-device client ID to the Day For It backend. One-tap recommendation feedback is stored with that anonymous ID so recommendations can be improved without creating an account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Privacy policy", destination: Self.privacyPolicyURL)
                }

                Section("Sources and attribution") {
                    Text("Marine forecasts, observations, and warnings are sourced from the Australian Bureau of Meteorology. Queensland tide predictions are sourced from Maritime Safety Queensland open data; predicted tide data is produced by the Australian Bureau of Meteorology and published through Queensland Government open data. Queensland wave observations and sea-surface temperature are sourced from Queensland Government Coastal Data System open data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Weather opportunity recommendations use forecast and marine forecast data from Open-Meteo, processed by the Day For It backend.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Day For It is an independent app and is not endorsed by Apple, the Bureau of Meteorology, Maritime Safety Queensland, or the Queensland Government.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Bureau of Meteorology", destination: Self.bomURL)
                    Link("Maritime Safety Queensland tide data", destination: Self.msqTideDataURL)
                    Link("Queensland wave data", destination: Self.qldWaveDataURL)
                    Link("Open-Meteo", destination: Self.openMeteoURL)
                    Link("Support and feedback", destination: Self.supportURL)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DayForItPalette.pageBackground.ignoresSafeArea())
            .tint(DayForItPalette.oceanDeep)
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
        return model.supportsManualLocation(latitude: lat, longitude: lon)
    }

    private var selectedPreset: LocationPreset? {
        model.availableLocationPresets.first(where: { $0.id == selectedPresetID })
    }

    private func matchingPresetID() -> String? {
        guard let saved = model.savedOverride else { return LocationPreset.all.first?.id }
        return model.availableLocationPresets.min { lhs, rhs in
            let left = hypot(lhs.latitude - saved.latitude, lhs.longitude - saved.longitude)
            let right = hypot(rhs.latitude - saved.latitude, rhs.longitude - saved.longitude)
            return left < right
        }?.id
    }

    private func coordinateText(latitude: Double, longitude: Double) -> String {
        String(format: "%.3f, %.3f", latitude, longitude)
    }

    private static let privacyPolicyURL = URL(string: "https://github.com/hmalc/day-for-it/blob/main/PRIVACY.md")!
    private static let supportURL = URL(string: "https://github.com/hmalc/day-for-it/issues")!
    private static let bomURL = URL(string: "https://www.bom.gov.au/")!
    private static let msqTideDataURL = URL(string: "https://www.tmr.qld.gov.au/msqinternet/tides/open-data")!
    private static let qldWaveDataURL = URL(string: "https://www.data.qld.gov.au/dataset/coastal-data-system-near-real-time-wave-data")!
    private static let openMeteoURL = URL(string: "https://open-meteo.com/")!
}
