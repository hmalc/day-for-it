import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    if let override = model.savedOverride {
                        Text("Using saved location: \(override.name)")
                        Button("Use default Cowley Beach", role: .destructive) {
                            model.clearLocationOverride()
                        }
                    } else {
                        Text("Using default location: Cowley Beach.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Set manual location") {
                    TextField("Name", text: $name)
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                    Button("Save override") {
                        guard let lat = Double(latitude), let lon = Double(longitude), !name.isEmpty else { return }
                        model.saveLocationOverride(name: name, latitude: lat, longitude: lon)
                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
