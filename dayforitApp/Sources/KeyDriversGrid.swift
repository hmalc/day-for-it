import SwiftUI

struct KeyDriversGrid: View {
    let items: [DriverMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                DriverMetricCard(item: item)
            }
        }
    }
}

struct DriverMetricCard: View {
    let item: DriverMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(item.label, systemImage: item.symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(item.accent ?? .secondary)

            Text(item.value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(BoatingUITheme.cardPadding)
        .cardSurface(.metric)
    }
}
