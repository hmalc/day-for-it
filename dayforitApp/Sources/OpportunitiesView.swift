import SwiftUI

struct OpportunitiesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let availableHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OpportunityHeaderCard(
                recommendation: model.topOpportunity,
                locationName: model.activeLocationName,
                updatedText: model.opportunityUpdatedText,
                isLoading: model.isLoadingOpportunities
            )

            OpportunityInterestSelector(
                selectedIDs: model.selectedOpportunityInterestIDs,
                onToggle: model.toggleOpportunityInterest
            )

            if let error = model.opportunityErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.opportunityRecommendations.isEmpty {
                OpportunityEmptyState(isLoading: model.isLoadingOpportunities)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.opportunityRecommendations) { recommendation in
                        OpportunityCard(
                            recommendation: recommendation,
                            feedbackLabel: model.opportunityFeedback[recommendation.id],
                            onFeedback: { feedback, label in
                                model.submitOpportunityFeedback(
                                    recommendation: recommendation,
                                    feedback: feedback,
                                    label: label
                                )
                            }
                        )
                    }
                }
            }

            if let attribution = model.opportunityAttribution {
                Text(attribution)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .topLeading)
        .task { await model.loadOpportunitiesIfNeeded() }
    }
}

private enum OpportunityLayout {
    static let cornerRadius: CGFloat = 20
}

private struct OpportunityHeaderCard: View {
    let recommendation: OpportunityRecommendation?
    let locationName: String
    let updatedText: String?
    let isLoading: Bool

    var body: some View {
        let style = OpportunityVisualStyle(recommendation: recommendation)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("This week's opportunities", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayForItPalette.oceanDeep.opacity(0.78))
                Spacer()
                if let recommendation {
                    Text(recommendation.priority.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(style.tint.opacity(0.16), in: Capsule())
                }
            }

            Text(recommendation?.title ?? "Scan the week")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(recommendation?.description ?? "Day For It looks for forecast patterns that can actually change your plans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                OpportunityInfoPill(systemImage: "mappin.and.ellipse", text: locationName, tint: DayForItPalette.oceanDeep)
                OpportunityInfoPill(systemImage: "clock", text: updatedText ?? (isLoading ? "Scanning" : "Not scanned"), tint: .secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(DayForItPalette.cardWash(accent: style.tint))
        }
        .clipShape(RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
        .shadow(color: style.tint.opacity(0.08), radius: 7, x: 0, y: 3)
    }
}

private struct OpportunityInterestSelector: View {
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OpportunityActivity.all) { activity in
                    Button {
                        onToggle(activity.id)
                    } label: {
                        Label(activity.label, systemImage: selectedIDs.contains(activity.id) ? "checkmark.circle.fill" : activity.systemImage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedIDs.contains(activity.id) ? DayForItPalette.sky.opacity(0.28) : Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedIDs.contains(activity.id) ? DayForItPalette.oceanDeep.opacity(0.28) : DayForItPalette.ocean.opacity(0.08), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedIDs.contains(activity.id) ? DayForItPalette.oceanDeep : .secondary)
                    .accessibilityLabel("\(activity.label), \(selectedIDs.contains(activity.id) ? "selected" : "not selected")")
                    .accessibilityHint("Toggles this interest and rescans the week.")
                }
            }
            .padding(.horizontal, 20)
        }
        .contentMargins(.horizontal, -20, for: .scrollContent)
    }
}

private struct OpportunityCard: View {
    let recommendation: OpportunityRecommendation
    let feedbackLabel: String?
    let onFeedback: (OpportunityFeedback, String) -> Void

    var body: some View {
        let style = OpportunityVisualStyle(recommendation: recommendation)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(OpportunityActivity.label(for: recommendation.activity), systemImage: iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.tint)
                    Text(recommendation.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                }
                Spacer(minLength: 8)
                OpportunityScoreBadge(score: recommendation.finalScore, tint: style.tint)
            }

            Text(recommendation.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                OpportunityInfoPill(systemImage: "calendar", text: windowText, tint: style.tint)
                OpportunityInfoPill(systemImage: "gauge.with.dots.needle.33percent", text: recommendation.confidence.capitalized, tint: .secondary)
            }

            if !recommendation.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(recommendation.reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(style.tint)
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            ForEach(Array(recommendation.riskFlags.prefix(2).enumerated()), id: \.offset) { _, risk in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(DayForItPalette.caution)
                    Text(risk)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            OpportunityFeedbackControls(feedbackLabel: feedbackLabel, onFeedback: onFeedback)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(DayForItPalette.cardWash(accent: style.tint))
                .overlay(
                    RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                        .strokeBorder(style.tint.opacity(0.12), lineWidth: 0.8)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        OpportunityActivity.all.first(where: { $0.id == recommendation.activity })?.systemImage ?? "sparkles"
    }

    private var windowText: String {
        let sameDay = Calendar.current.isDate(recommendation.window.start, inSameDayAs: recommendation.window.end)
        if sameDay {
            return "\(Self.dayFormatter.string(from: recommendation.window.start)) \(Self.timeFormatter.string(from: recommendation.window.start))-\(Self.timeFormatter.string(from: recommendation.window.end))"
        }
        return "\(Self.dayFormatter.string(from: recommendation.window.start))-\(Self.dayFormatter.string(from: recommendation.window.end))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()
}

private struct OpportunityFeedbackControls: View {
    let feedbackLabel: String?
    let onFeedback: (OpportunityFeedback, String) -> Void

    var body: some View {
        if let feedbackLabel {
            Label(feedbackLabel, systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayForItPalette.oceanDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        } else {
            HStack(spacing: 8) {
                feedbackButton("Good", systemImage: "hand.thumbsup.fill", feedback: .init(didAct: "yes", outcome: "good", reason: nil, freeText: nil))
                feedbackButton("Mostly", systemImage: "checkmark.circle.fill", feedback: .init(didAct: "yes", outcome: "mostly_good", reason: nil, freeText: nil))
                feedbackButton("Skip", systemImage: "forward.fill", feedback: .init(didAct: "no", outcome: nil, reason: "busy", freeText: nil))
                Menu {
                    ForEach(badReasons, id: \.value) { item in
                        Button(item.label) {
                            onFeedback(
                                .init(didAct: "yes", outcome: "bad", reason: item.value, freeText: nil),
                                "Bad call"
                            )
                        }
                    }
                    Button("Not relevant") {
                        onFeedback(.init(didAct: "not_relevant", outcome: nil, reason: "not_interested", freeText: nil), "Not relevant")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(DayForItPalette.sky.opacity(0.16), in: Circle())
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("More feedback")
            }
            .padding(.top, 2)
        }
    }

    private func feedbackButton(_ label: String, systemImage: String, feedback: OpportunityFeedback) -> some View {
        Button {
            onFeedback(feedback, feedbackLabel(for: label))
        } label: {
            Label(label, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DayForItPalette.sky.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(DayForItPalette.oceanDeep)
    }

    private func feedbackLabel(for label: String) -> String {
        switch label {
        case "Good": return "Good call"
        case "Mostly": return "Mostly good"
        case "Skip": return "Didn't do it"
        default: return label
        }
    }

    private var badReasons: [(label: String, value: String)] {
        [
            ("Too wet", "too_wet"),
            ("Too hot", "too_hot"),
            ("Too windy", "too_windy"),
            ("Too cold", "too_cold"),
            ("Rain interrupted", "rain_interrupted"),
            ("Forecast wrong", "forecast_wrong"),
            ("Other", "other")
        ]
    }
}

private struct OpportunityInfoPill: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OpportunityScoreBadge: View {
    let score: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(Int(score.rounded()))")
                .font(.headline.weight(.bold).monospacedDigit())
            Text("score")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(tint)
        .frame(width: 52, height: 52)
        .background(tint.opacity(0.10), in: Circle())
        .accessibilityLabel("Score \(Int(score.rounded())) out of 100")
    }
}

private struct OpportunityEmptyState: View {
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(isLoading ? "Scanning the week" : "No strong opportunities yet", systemImage: isLoading ? "sparkles" : "cloud")
                .font(.headline.weight(.semibold))
            Text(isLoading ? "Looking for useful forecast windows." : "The engine stays quiet when nothing looks likely to change your plans.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
    }
}

private struct OpportunityVisualStyle {
    let tint: Color

    init(recommendation: OpportunityRecommendation?) {
        guard let recommendation else {
            tint = DayForItPalette.oceanDeep
            return
        }
        if recommendation.verdict == "recommended" || recommendation.priority == "high" {
            tint = DayForItPalette.skyDeep
        } else if recommendation.verdict == "watch" {
            tint = DayForItPalette.okay
        } else {
            tint = DayForItPalette.hold
        }
    }
}

#Preview {
    OpportunitiesView(availableHeight: 700)
        .environmentObject(AppModel())
}
