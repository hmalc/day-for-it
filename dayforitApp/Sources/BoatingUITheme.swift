import SwiftUI
import PleasantnessEngine

extension DayVerdict {
    var tint: Color {
        switch self {
        case .dayForIt: return .green
        case .decent: return .mint
        case .ifYouMust: return .yellow
        case .poor: return .orange
        case .notAChance: return .red
        }
    }
}

/// Tint for an optional verdict; unknown days read as neutral.
func verdictTint(_ verdict: DayVerdict?) -> Color {
    verdict?.tint ?? Color(.systemGray)
}

/// Five-segment ladder meter — the one visual encoding of a verdict.
struct VerdictMeter: View {
    let verdict: DayVerdict?
    var segmentWidth: CGFloat = 14
    var segmentHeight: CGFloat = 5

    var body: some View {
        let filled = verdict.map { $0.rank + 1 } ?? 0
        HStack(spacing: 3) {
            ForEach(0 ..< 5, id: \.self) { idx in
                Capsule()
                    .fill(idx < filled ? verdictTint(verdict) : Color(.tertiarySystemFill))
                    .frame(width: segmentWidth, height: segmentHeight)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Flat inset-grouped card, matching system grouped lists.
struct GroupedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

extension View {
    func groupedCard() -> some View {
        modifier(GroupedCardModifier())
    }
}
