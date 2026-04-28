import SwiftUI
import WeatherCore

struct SourceAndUpdateInfoCard: View {
    let generatedAt: Date?
    let quality: MarineForecastOutput.DataQuality?
    let disclaimer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source and update info")
                .font(.headline.weight(.semibold))
            if let generatedAt {
                infoRow("Updated", value: Self.relativeFormatter.localizedString(for: generatedAt, relativeTo: Date()))
            }
            infoRow("Data quality", value: quality?.rawValue ?? "Unavailable")
            Text(disclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(BoatingUITheme.cardPadding)
        .cardSurface(.section)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
