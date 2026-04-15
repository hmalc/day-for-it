import SwiftUI

struct DetailedConditionsCard: View {
    let rows: [ConditionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detailed conditions")
                .font(.headline.weight(.semibold))

            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack {
                    Text(row.label)
                        .font(.body)
                    Spacer()
                    Text(row.value)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if idx < rows.count - 1 { Divider().opacity(0.45) }
            }
        }
        .padding(BoatingUITheme.cardPadding)
        .cardSurface(.section)
    }
}

struct ConditionRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}
