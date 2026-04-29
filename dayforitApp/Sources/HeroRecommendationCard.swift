import SwiftUI
import WeatherCore

struct HeroRecommendationCard: View {
    let locationName: String
    let summary: DailyMarineSummary?
    let warningText: String?
    let windText: String
    let wavesText: String
    let tideText: String
    let supporting: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let style = CalmnessVisualStyle(rating: summary?.rating)
        ZStack(alignment: .topLeading) {
            HeroFluidBackground(style: style, reduceMotion: reduceMotion)
                .clipShape(RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(locationName.uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let summary {
                        Text(summary.rating.label.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(style.tint.opacity(0.2), in: Capsule())
                    }
                }

                Text(primaryTitle)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(2)

                Text(supporting)
                    .font(.body)
                    .foregroundStyle(.secondary)

                ViewThatFits {
                    HStack(spacing: 10) {
                        HeroMetricPill(label: "Wind", value: windText, symbol: "wind")
                        HeroMetricPill(label: "Waves", value: wavesText, symbol: "water.waves")
                        HeroMetricPill(label: "Tide", value: tideText, symbol: "arrow.up.and.down")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            HeroMetricPill(label: "Wind", value: windText, symbol: "wind")
                            HeroMetricPill(label: "Waves", value: wavesText, symbol: "water.waves")
                        }
                        HeroMetricPill(label: "Tide", value: tideText, symbol: "arrow.up.and.down")
                    }
                }

                if let warningText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(DayForItPalette.hold)
                        Text(warningText)
                            .font(.footnote)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .background(DayForItPalette.caution.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(BoatingUITheme.heroPadding)
        }
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .cardSurface(.hero(style))
        .animation(.easeInOut(duration: 0.35), value: summary?.rating)
    }

    private var primaryTitle: String {
        guard let rating = summary?.rating else { return "Loading conditions" }
        switch rating {
        case .green: return "Good to go"
        case .amber: return "Use care today"
        case .red: return "Not recommended"
        }
    }
}

struct HeroMetricPill: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.6)
        }
    }
}

struct HeroFluidBackground: View {
    let style: CalmnessVisualStyle
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemGroupedBackground),
                    DayForItPalette.sky.opacity(0.12),
                    Color(uiColor: .tertiarySystemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if reduceMotion {
                Circle()
                    .fill(style.tint.opacity(0.12))
                    .blur(radius: 32)
                    .offset(x: -40, y: -20)
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let cycle = t.truncatingRemainder(dividingBy: 16) / 16
                    ZStack {
                        Circle()
                            .fill(style.tint.opacity(0.16))
                            .frame(width: 260, height: 260)
                            .blur(radius: 34)
                            .offset(x: CGFloat(sin(cycle * .pi * 2) * 24), y: CGFloat(cos(cycle * .pi * 2) * 14))
                        Ellipse()
                            .fill(style.tint.opacity(0.12))
                            .frame(width: 300, height: 170)
                            .blur(radius: 40)
                            .offset(x: CGFloat(cos(cycle * .pi * 2) * -18), y: CGFloat(sin(cycle * .pi * 2) * 10 + 35))
                    }
                }
            }
        }
    }
}
