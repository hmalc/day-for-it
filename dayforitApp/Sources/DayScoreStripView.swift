import SwiftUI
import WeatherCore

struct DayScoreStripView: View {
    let days: [DailyMarineSummary]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                    Button {
                        onSelect(idx)
                    } label: {
                        VStack(spacing: 6) {
                            Text(shortWeekday(day.dayStart))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(day.pleasantness.map { "\(Int($0.rounded()))" } ?? "--")
                                .font(.headline.monospacedDigit())
                            Circle()
                                .fill(colorForScore(day.pleasantness))
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(idx == selectedIndex ? DayForItPalette.sky.opacity(0.22) : DayForItPalette.sky.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func colorForScore(_ score: Double?) -> Color {
        guard let score else { return .secondary.opacity(0.5) }
        if score >= 75 { return DayForItPalette.calm }
        if score >= 55 { return DayForItPalette.okay }
        if score >= 35 { return DayForItPalette.caution }
        return DayForItPalette.hold
    }
}
