import SwiftUI

struct OpportunitiesView: View {
    @EnvironmentObject private var model: AppModel

    let availableHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good day for it?")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("Boating windows only. Just the calls worth checking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            if let error = model.opportunityErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            BoatingAnchorCard(
                badgeText: model.heroOpportunitySummary.badgeText,
                headlineText: model.decisionHeadlineText,
                summaryText: model.decisionSummaryText,
                windText: model.heroWindText,
                wavesText: model.heroWavesText,
                tideText: model.heroTideText,
                warningText: model.warningBanner,
                updatedText: model.lastUpdatedText,
                style: CalmnessVisualStyle(rating: model.heroOpportunitySummary.tone)
            )

            OpportunityAnchorSlot(
                activityID: "boating",
                emptyTitle: "No strong boating window yet",
                emptyDescription: "Day For It will stay quiet unless a genuinely useful calm window shows up.",
                recommendation: model.backendBoatingRecommendation,
                feedbackLabel: feedbackLabel(for: "boating"),
                onFeedback: submitFeedback
            )

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

    private func feedbackLabel(for activityID: String) -> String? {
        guard let recommendation = model.opportunityRecommendation(for: activityID) else { return nil }
        return model.opportunityFeedback[recommendation.id]
    }

    private func submitFeedback(_ recommendation: OpportunityRecommendation, _ feedback: OpportunityFeedback, _ label: String) {
        model.submitOpportunityFeedback(
            recommendation: recommendation,
            feedback: feedback,
            label: label
        )
    }
}

private enum OpportunityLayout {
    static let cornerRadius: CGFloat = 18
}

private struct BoatingAnchorCard: View {
    let badgeText: String
    let headlineText: String
    let summaryText: String
    let windText: String
    let wavesText: String
    let tideText: String
    let warningText: String?
    let updatedText: String?
    let style: CalmnessVisualStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Boating", systemImage: "sailboat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayForItPalette.oceanDeep.opacity(0.78))
                Spacer()
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(style.tint.opacity(0.16), in: Capsule())
            }

            Text(headlineText)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                OpportunityInfoPill(systemImage: "wind", text: windText, tint: .secondary)
                OpportunityInfoPill(systemImage: "water.waves", text: wavesText, tint: DayForItPalette.oceanDeep)
                OpportunityInfoPill(systemImage: "arrow.up.and.down", text: tideText, tint: DayForItPalette.calm)
            }

            if let updatedText {
                Label(updatedText, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let warningText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(DayForItPalette.caution)
                    Text(warningText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                .fill(DayForItPalette.cardBackground)
                .overlay(DayForItPalette.cardWash(accent: style.tint))
                .overlay(
                    RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                        .strokeBorder(DayForItPalette.hairline, lineWidth: 0.7)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
        .shadow(color: DayForItPalette.elevatedShadow, radius: 8, x: 0, y: 4)
    }
}

private struct OpportunityAnchorSlot: View {
    let activityID: String
    let emptyTitle: String
    let emptyDescription: String
    let recommendation: OpportunityRecommendation?
    let feedbackLabel: String?
    let onFeedback: (OpportunityRecommendation, OpportunityFeedback, String) -> Void

    var body: some View {
        if let recommendation {
            OpportunityCard(
                recommendation: recommendation,
                feedbackLabel: feedbackLabel,
                onFeedback: { feedback, label in
                    onFeedback(recommendation, feedback, label)
                }
            )
        } else {
            AnchorEmptyCard(
                activityID: activityID,
                title: emptyTitle,
                description: emptyDescription
            )
        }
    }
}

private struct AnchorEmptyCard: View {
    let activityID: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(OpportunityActivity.label(for: activityID), systemImage: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayForItPalette.oceanDeep.opacity(0.76))
            Text(title)
                .font(.headline.weight(.semibold))
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                .fill(DayForItPalette.cardBackground)
                .overlay(DayForItPalette.cardWash(accent: DayForItPalette.oceanDeep.opacity(0.7)))
                .overlay(
                    RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous)
                        .strokeBorder(DayForItPalette.hairline, lineWidth: 0.7)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
    }

    private var iconName: String {
        OpportunityActivity.all.first(where: { $0.id == activityID })?.systemImage ?? "sparkles"
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

            OpportunityMarineEvidenceStrip(recommendation: recommendation)

            HStack(spacing: 6) {
                OpportunityInfoPill(systemImage: "calendar", text: windowText, tint: style.tint)
                OpportunityInfoPill(systemImage: evidenceSystemImage, text: evidenceLabel, tint: .secondary)
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
                .fill(DayForItPalette.cardBackground)
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

    private var evidenceSystemImage: String {
        hasKnownSeaData ? "checkmark.seal.fill" : "wind"
    }

    private var evidenceLabel: String {
        if recommendation.analysis?.band == "wind_led_watch" {
            return "Wind only"
        }
        if hasKnownSeaData {
            return waveSwellEvidenceLabel
        }
        switch recommendation.confidence.lowercased() {
        case "high":
            return "Wind/tide/rain"
        case "medium":
            return "Partial inputs"
        default:
            return "Limited inputs"
        }
    }

    private var waveSwellEvidenceLabel: String {
        let signals = recommendation.analysis?.dataSignals ?? []
        let hasWave = signals.contains { $0.lowercased().hasPrefix("wave ") }
        let hasSwell = signals.contains { $0.lowercased().hasPrefix("swell ") }
        let hasPeriod = signals.contains { $0.lowercased().hasPrefix("period ") }

        if hasWave && hasSwell && hasPeriod {
            return "Wave + swell"
        }
        if hasWave && hasSwell {
            return "Wave + swell"
        }
        if hasWave {
            return "Wave height"
        }
        if hasSwell {
            return "Swell height"
        }
        return "Wave/swell model"
    }

    private var hasKnownSeaData: Bool {
        let signals = recommendation.analysis?.dataSignals ?? []
        let hasSeaSignal = signals.contains { signal in
            let lower = signal.lowercased()
            return lower.hasPrefix("wave ") || lower.hasPrefix("swell ")
        }
        let seaDetail = recommendation.analysis?.factors.first { factor in
            let lowerID = factor.id.lowercased()
            let lowerLabel = factor.label.lowercased()
            return lowerID.contains("sea") || lowerID.contains("swell") || lowerID.contains("wave") ||
                lowerLabel.contains("sea") || lowerLabel.contains("swell") || lowerLabel.contains("wave")
        }?.detail.lowercased() ?? ""
        let sourceStatus = recommendation.analysis?.sourceStatus.map { $0.lowercased() } ?? []
        let waveMissing = sourceStatus.contains { $0.contains("wave_height") && $0.contains("missing") }
        let swellMissing = sourceStatus.contains { $0.contains("swell_height") && $0.contains("missing") }
        let isWindEstimated = recommendation.analysis?.band == "wind_led_watch" || seaDetail.contains("estimated from wind")

        return (hasSeaSignal || seaDetail.contains("roughness index")) && !(waveMissing && swellMissing) && !isWindEstimated
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

private struct OpportunityMarineEvidenceStrip: View {
    let recommendation: OpportunityRecommendation

    var body: some View {
        let evidence = marineEvidence
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: evidence.isConfirmed ? "checkmark.seal.fill" : "wind")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint(for: evidence))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(evidence.title)
                    .font(.caption.weight(.semibold))
                Text(evidence.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint(for: evidence).opacity(evidence.isConfirmed ? 0.10 : 0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var marineEvidence: OpportunityMarineEvidence {
        let signals = recommendation.analysis?.dataSignals ?? []
        let seaSignals = signals.filter { signal in
            let lower = signal.lowercased()
            return lower.hasPrefix("wave ") || lower.hasPrefix("swell ") || lower.hasPrefix("period ")
        }
        let seaDetail = seaFactorDetail?.lowercased() ?? ""
        let sourceStatus = recommendation.analysis?.sourceStatus.map { $0.lowercased() } ?? []
        let waveMissing = sourceStatus.contains { $0.contains("wave_height") && $0.contains("missing") }
        let swellMissing = sourceStatus.contains { $0.contains("swell_height") && $0.contains("missing") }
        let isWindEstimated = recommendation.analysis?.band == "wind_led_watch" || seaDetail.contains("estimated from wind")

        if !seaSignals.isEmpty && !(waveMissing && swellMissing) && !isWindEstimated {
            return OpportunityMarineEvidence(
                title: "Wave/swell forecast data",
                detail: seaSignals.prefix(3).joined(separator: " · "),
                isConfirmed: true
            )
        }

        if seaDetail.contains("roughness index") && !isWindEstimated {
            return OpportunityMarineEvidence(
                title: "Wave/swell model",
                detail: seaFactorDetail ?? "Wave height or swell height is part of this score.",
                isConfirmed: true
            )
        }

        return OpportunityMarineEvidence(
            title: "Wind-only candidate",
            detail: "Promising wind is supplementary until wave height and swell data confirm.",
            isConfirmed: false
        )
    }

    private var seaFactorDetail: String? {
        let factor = recommendation.analysis?.factors.first { factor in
            let lowerID = factor.id.lowercased()
            let lowerLabel = factor.label.lowercased()
            return lowerID.contains("sea") || lowerID.contains("swell") || lowerID.contains("wave") ||
                lowerLabel.contains("sea") || lowerLabel.contains("swell") || lowerLabel.contains("wave")
        }
        let detail = factor?.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail?.isEmpty == false ? detail : nil
    }

    private func tint(for evidence: OpportunityMarineEvidence) -> Color {
        evidence.isConfirmed ? DayForItPalette.oceanDeep : DayForItPalette.okay
    }
}

private struct OpportunityMarineEvidence {
    let title: String
    let detail: String
    let isConfirmed: Bool
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
        .background(DayForItPalette.cardBackground, in: RoundedRectangle(cornerRadius: OpportunityLayout.cornerRadius, style: .continuous))
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
