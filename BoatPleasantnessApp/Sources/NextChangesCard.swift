import SwiftUI

struct NextChangesCard: View {
    let rows: [NextChangeItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What changes next")
                .font(.headline.weight(.semibold))
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                NextChangeRow(item: row)
                if idx < rows.count - 1 {
                    Divider().opacity(0.45)
                }
            }
        }
        .padding(BoatingUITheme.cardPadding)
        .cardSurface(.section)
    }
}

struct NextChangeItem: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

struct NextChangeRow: View {
    let item: NextChangeItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
