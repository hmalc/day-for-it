import SwiftUI
import WeatherCore
import PleasantnessEngine

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false
    @State private var selectedTab: TopTab = .summary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum TopTab: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case opportunities = "Week"
        case tides = "Tides"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    ForEach(TopTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if selectedTab == .summary {
                    GeometryReader { geo in
                        ScrollView {
                            summaryContent(
                                isSkeleton: model.isLoading && model.output == nil,
                                availableHeight: geo.size.height
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollBounceBehavior(.always)
                        .refreshable { await model.refresh() }
                    }
                } else if selectedTab == .opportunities {
                    GeometryReader { geo in
                        ScrollView {
                            OpportunitiesView(availableHeight: geo.size.height)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollBounceBehavior(.always)
                        .refreshable { await model.refreshOpportunities() }
                    }
                } else {
                    GeometryReader { geo in
                        ScrollView {
                            if model.isLoading && model.tideForecast == nil {
                                TideLoadingView(
                                    reduceMotion: reduceMotion,
                                    availableHeight: geo.size.height
                                )
                            } else {
                                ImmersiveTidesView(
                                    pages: model.tidePageViewData,
                                    statusMessage: model.tideStatusMessage,
                                    availableHeight: geo.size.height
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollBounceBehavior(.always)
                        .refreshable { await model.refresh() }
                    }
                }
            }
            .background(DayForItPalette.pageBackground.ignoresSafeArea())
            .tint(DayForItPalette.oceanDeep)
            .navigationTitle("Day For It")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(DayForItPalette.oceanDeep.opacity(0.72))
                        Text(model.activeLocationName)
                            .font(.subheadline.weight(.semibold))
                        if let lastUpdatedText = model.lastUpdatedText {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(lastUpdatedText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(model.lastUpdatedText.map { "\(model.activeLocationName), updated \($0)" } ?? model.activeLocationName)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .task { model.startup() }
        }
    }

    @ViewBuilder
    private func summaryContent(isSkeleton: Bool, availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: WeatherSectionLayout.sectionSpacing) {
            if isSkeleton {
                ForecastLoadingView(reduceMotion: reduceMotion)
            } else {
                CompactHeroRecommendationCard(
                    tone: model.heroOpportunitySummary.tone,
                    badgeText: model.heroOpportunitySummary.badgeText,
                    headlineText: model.heroOpportunitySummary.headline,
                    summaryText: model.decisionSummaryText,
                    windText: model.heroWindText,
                    wavesText: model.heroWavesText,
                    tideText: model.heroTideText,
                    warningText: model.warningBanner,
                    minHeight: heroCardHeight(availableHeight: availableHeight),
                    usesRoomyLayout: usesRoomySummaryLayout(availableHeight: availableHeight)
                )

                if model.isLoading {
                    RefreshingForecastPill()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                FourDayForecastCardsSection(
                    pages: model.fourDayDetailPages,
                    selectedIndex: model.selectedDayIndex,
                    cardHeight: forecastCardHeight(availableHeight: availableHeight),
                    onSelectDay: { index in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            model.select(dayIndex: index)
                        }
                    }
                )

                BPSourceInfoCard(
                    generatedAt: model.output?.generatedAt,
                    quality: model.output?.dataQuality,
                    disclaimer: model.disclaimer
                )
            }

            if !isSkeleton, let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .topLeading)
    }

    private func heroCardHeight(availableHeight: CGFloat) -> CGFloat {
        guard usesRoomySummaryLayout(availableHeight: availableHeight) else { return 0 }
        return min(max(196, availableHeight * 0.27), 232)
    }

    private func forecastCardHeight(availableHeight: CGFloat) -> CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return 280 }
        let flexibleHeight = availableHeight - heroCardHeight(availableHeight: availableHeight) - 198
        return min(max(264, flexibleHeight), 430)
    }

    private func usesRoomySummaryLayout(availableHeight: CGFloat) -> Bool {
        !dynamicTypeSize.isAccessibilitySize && availableHeight >= 650
    }
}

private enum WeatherSectionLayout {
    static let sectionSpacing: CGFloat = 10
    static let cornerRadius: CGFloat = 20
}

private struct CompactHeroRecommendationCard: View {
    let tone: BoatDayRating?
    let badgeText: String
    let headlineText: String
    let summaryText: String
    let windText: String
    let wavesText: String
    let tideText: String
    let warningText: String?
    let minHeight: CGFloat
    let usesRoomyLayout: Bool

    var body: some View {
        let style = BPCalmStyle(rating: tone)
        VStack(alignment: .leading, spacing: usesRoomyLayout ? 12 : 9) {
            HStack {
                Label("Ocean outlook", systemImage: "sailboat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayForItPalette.oceanDeep.opacity(0.74))
                Spacer()
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(style.tint.opacity(0.2), in: Capsule())
            }

            Text(headlineText)
                .font(headlineFont)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryText)
                .font(usesRoomyLayout ? .subheadline : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(usesRoomyLayout ? 2 : 2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            if usesRoomyLayout {
                Spacer(minLength: 0)
                HStack(alignment: .top, spacing: 12) {
                    heroSignal("Wind", value: windText, systemImage: "wind", accent: .secondary)
                    heroSignal("Waves", value: wavesText, systemImage: "water.waves", accent: DayForItPalette.oceanDeep)
                    heroSignal("Tide", value: tideText, systemImage: "arrow.up.and.down", accent: DayForItPalette.calm)
                }
            } else {
                HStack(spacing: 5) {
                    Label(windText, systemImage: "wind")
                    Text("·")
                    Label(wavesText, systemImage: "water.waves")
                    Text("·")
                    Label(tideText, systemImage: "arrow.up.and.down")
                    if warningText != nil {
                        Text("·")
                        Label("Warning", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(DayForItPalette.caution)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
        }
        .padding(usesRoomyLayout ? 16 : 14)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    DayForItPalette.cardWash(accent: style.tint)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
        .shadow(color: style.tint.opacity(0.08), radius: 7, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.35), value: tone)
    }

    private var headlineFont: Font {
        if usesRoomyLayout {
            return .system(.largeTitle, design: .rounded, weight: .semibold)
        }
        return .system(.title2, design: .rounded, weight: .semibold)
    }

    @ViewBuilder
    private func heroSignal(_ title: String, value: String, systemImage: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(accent)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct FourDayForecastCardsSection: View {
    let pages: [FourDayDetailPage]
    let selectedIndex: Int
    let cardHeight: CGFloat
    let onSelectDay: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 20)

            if pages.isEmpty {
                Text("Detailed daily forecast is loading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            } else {
                ScrollViewReader { proxy in
                    FourDayScoreSelector(
                        pages: pages,
                        selectedIndex: selectedIndex,
                        onSelectDay: { sourceIndex in
                            onSelectDay(sourceIndex)
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                proxy.scrollTo(sourceIndex, anchor: .center)
                            }
                        }
                    )
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(pages) { page in
                                ForecastDayCard(
                                    page: page,
                                    isSelected: page.sourceIndex == selectedIndex,
                                    cardHeight: cardHeight
                                )
                                    .frame(width: 276)
                                    .id(page.sourceIndex)
                                    .contentShape(RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
                                    .onTapGesture {
                                        select(page, using: proxy)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(accessibilityLabel(for: page))
                                    .accessibilityHint(accessibilityHint(for: page))
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction {
                                        select(page, using: proxy)
                                    }
                                }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        }
        .padding(.horizontal, -20)
    }

    private var sectionTitle: String {
        if pages.count >= 4 { return "Next 4 days" }
        if pages.count == 1 { return "Next forecast day" }
        return "Next \(pages.count) forecast days"
    }

    private func accessibilityLabel(for page: FourDayDetailPage) -> String {
        let score = page.scoreValue.map { "\(Int($0.rounded())) out of 100" } ?? "score unavailable"
        return "\(page.dayLabel), \(page.rating.label), \(score). \(page.summaryText)"
    }

    private func accessibilityHint(for page: FourDayDetailPage) -> String {
        page.sourceIndex == selectedIndex ? "Selected forecast day." : "Selects this forecast day."
    }

    private func select(_ page: FourDayDetailPage, using proxy: ScrollViewProxy) {
        onSelectDay(page.sourceIndex)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            proxy.scrollTo(page.sourceIndex, anchor: .center)
        }
    }
}

private struct FourDayScoreSelector: View {
    let pages: [FourDayDetailPage]
    let selectedIndex: Int
    let onSelectDay: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(pages.prefix(4)), id: \.id) { page in
                Button {
                    onSelectDay(page.sourceIndex)
                } label: {
                    let isSelected = page.sourceIndex == selectedIndex
                    VStack(spacing: 3) {
                        Text(compactDayLabel(page.dayLabel))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(page.scoreText)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(tintFor(page.rating))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? tintFor(page.rating).opacity(0.10) : DayForItPalette.sky.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? tintFor(page.rating).opacity(0.34) : Color.clear, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func compactDayLabel(_ label: String) -> String {
        switch label {
        case "Today": return "Today"
        case "Tomorrow": return "Tom"
        default: return String(label.prefix(3))
        }
    }

    private func tintFor(_ rating: BoatDayRating) -> Color {
        BPCalmStyle(rating: rating).tint
    }
}

private struct ForecastDayCard: View {
    let page: FourDayDetailPage
    let isSelected: Bool
    let cardHeight: CGFloat

    var body: some View {
        let tint = tintFor(page.rating)
        let driverRows = forecastDriverRows
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(page.dayLabel)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        if page.isBest {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DayForItPalette.sun)
                        }
                    }
                    Text(page.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ScoreDial(score: page.scoreValue, rating: page.rating)
            }

            Text(page.summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(isRoomy ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForecastInfoPill(title: "Rating", value: page.rating.label, tint: tint)
                ForecastInfoPill(title: "Confidence", value: page.confidenceText, tint: .secondary)
            }

            if isRoomy, let contextText = page.contextText {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Forecast basis")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(contextText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.86)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DayForItPalette.sky.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !driverRows.isEmpty {
                VStack(alignment: .leading, spacing: isRoomy ? 8 : 6) {
                    if isRoomy {
                        Text("Main factors")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(driverRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: row.tone.systemImage)
                                .font(.caption2)
                                .foregroundStyle(row.tone.tint)
                            Text(row.text)
                                .font(.caption)
                                .foregroundStyle(row.tone == .neutral ? .secondary : .primary)
                                .lineLimit(isRoomy ? 2 : 1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: page.warningText == "No warnings" ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text(page.warningText)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(page.warningText == "No warnings" ? DayForItPalette.calm : DayForItPalette.caution)
        }
        .padding(14)
        .frame(height: cardHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    DayForItPalette.cardWash(accent: tint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? tint.opacity(0.42) : DayForItPalette.ocean.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
        .shadow(color: tint.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 10 : 5, x: 0, y: isSelected ? 5 : 2)
        .scaleEffect(isSelected ? 1.0 : 0.985)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isSelected)
    }

    private var isRoomy: Bool {
        cardHeight >= 340
    }

    private var forecastDriverRows: [ForecastDriverRow] {
        page.topDrivers.map {
            ForecastDriverRow(text: $0, tone: driverTone(for: $0))
        }
    }

    private func driverTone(for text: String) -> ForecastDriverTone {
        let lower = text.lowercased()
        if lower.contains("no active") {
            return .positive
        }
        if [
            "strong", "high wind", "fresh winds", "rough", "lumpy", "awkward",
            "high rain", "warning", "cap the score", "reducing", "gusts"
        ].contains(where: lower.contains) {
            return .negative
        }
        if [
            "light winds", "manageable winds", "low seas", "modest seas",
            "favorable", "favourable", "comfortable", "best current window"
        ].contains(where: lower.contains) {
            return .positive
        }
        return .neutral
    }

    private func tintFor(_ rating: BoatDayRating) -> Color {
        BPCalmStyle(rating: rating).tint
    }
}

private struct ForecastDriverRow {
    let text: String
    let tone: ForecastDriverTone
}

private enum ForecastDriverTone {
    case positive
    case neutral
    case negative

    var systemImage: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .negative: return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .positive: return DayForItPalette.calm
        case .neutral: return .secondary
        case .negative: return DayForItPalette.hold
        }
    }
}

private struct ScoreDial: View {
    let score: Double?
    let rating: BoatDayRating

    var body: some View {
        let clamped = min(max((score ?? 0) / 100.0, 0), 1)
        let tint = tintFor(rating)
        ZStack {
            Circle()
                .stroke(DayForItPalette.ocean.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(score.map { "\(Int($0.rounded()))" } ?? "--")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Score \(score.map { "\(Int($0.rounded()))" } ?? "unavailable")")
    }

    private func tintFor(_ rating: BoatDayRating) -> Color {
        BPCalmStyle(rating: rating).tint
    }
}

private struct ForecastInfoPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DayForItPalette.sun.opacity(0.03))
                )
        )
    }
}

private struct RefreshingForecastPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text("Refreshing forecast")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ForecastLoadingView: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking forecast")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BPLoadingBlock(width: 96, height: 14, cornerRadius: 6, reduceMotion: reduceMotion)
                    Spacer()
                    BPLoadingBlock(width: 48, height: 20, cornerRadius: 10, reduceMotion: reduceMotion)
                }
                BPLoadingBlock(height: 22, cornerRadius: 8, reduceMotion: reduceMotion)
                BPLoadingBlock(width: 240, height: 14, cornerRadius: 6, reduceMotion: reduceMotion)
                BPLoadingBlock(width: 260, height: 12, cornerRadius: 6, reduceMotion: reduceMotion)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                BPLoadingBlock(width: 104, height: 18, cornerRadius: 6, reduceMotion: reduceMotion)
                HStack(spacing: 6) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        BPLoadingBlock(height: 44, cornerRadius: 12, reduceMotion: reduceMotion)
                    }
                }
                BPLoadingBlock(height: 180, cornerRadius: WeatherSectionLayout.cornerRadius, reduceMotion: reduceMotion)
            }

            BPLoadingBlock(height: 62, cornerRadius: WeatherSectionLayout.cornerRadius, reduceMotion: reduceMotion)
        }
    }
}

private struct TideLoadingView: View {
    let reduceMotion: Bool
    let availableHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                BPLoadingBlock(width: 74, height: 24, cornerRadius: 7, reduceMotion: reduceMotion)
                BPLoadingBlock(width: 210, height: 16, cornerRadius: 6, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            HStack(spacing: 12) {
                BPLoadingBlock(height: 54, cornerRadius: 14, reduceMotion: reduceMotion)
                BPLoadingBlock(height: 54, cornerRadius: 14, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                BPLoadingBlock(height: loadingChartHeight, cornerRadius: 18, reduceMotion: reduceMotion)
                HStack {
                    BPLoadingBlock(width: 34, height: 11, cornerRadius: 4, reduceMotion: reduceMotion)
                    Spacer()
                    BPLoadingBlock(width: 34, height: 11, cornerRadius: 4, reduceMotion: reduceMotion)
                    Spacer()
                    BPLoadingBlock(width: 34, height: 11, cornerRadius: 4, reduceMotion: reduceMotion)
                    Spacer()
                    BPLoadingBlock(width: 34, height: 11, cornerRadius: 4, reduceMotion: reduceMotion)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading tide data")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .topLeading)
    }

    private var loadingChartHeight: CGFloat {
        max(320, availableHeight - 235)
    }
}

private struct BPLoadingBlock: View {
    var width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    let reduceMotion: Bool

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat, reduceMotion: Bool) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DayForItPalette.sky.opacity(0.18))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
            )
            .modifier(ShimmerModifier(isDisabled: reduceMotion))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct ShimmerModifier: ViewModifier {
    let isDisabled: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !isDisabled {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.72)
                        .offset(x: geo.size.width * phase)
                    }
                    .allowsHitTesting(false)
                    .blendMode(.plusLighter)
                }
            }
            .onAppear {
                guard !isDisabled else { return }
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.35
                }
            }
    }
}

private struct RefinedKeyDriversSection: View {
    let items: [DriverMetric]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key drivers")
                .font(.headline.weight(.semibold))
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        Label(item.label, systemImage: item.symbol)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(item.accent ?? .secondary)
                        Text(item.value)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DayForItPalette.sky.opacity(0.08))
                            )
                    )
                }
            }
        }
    }
}

private struct ImmersiveTidesView: View {
    let pages: [TideCardViewData]
    let statusMessage: String?
    let availableHeight: CGFloat
    @State private var selectedPageID: Date?
    @State private var probe: TideProbe?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let currentPage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Tides")
                            .font(.title2.weight(.semibold))
                        Spacer()
                        Text(currentPage.windowLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(probe?.stateLabel ?? currentPage.stateLabel)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                HStack(alignment: .top, spacing: 12) {
                    tideInfoColumn(title: "High", value: eventText(prefix: "High", event: currentPage.nextHigh), accent: DayForItPalette.oceanDeep)
                    Divider().frame(height: 52)
                    tideInfoColumn(title: "Low", value: eventText(prefix: "Low", event: currentPage.nextLow), accent: DayForItPalette.calm)
                }
                .padding(.horizontal, 20)

                tidePageSelector(currentPage: currentPage)
                    .padding(.horizontal, 20)

                ZStack {
                    LinearGradient(
                        colors: [
                            DayForItPalette.sky.opacity(0.18),
                            DayForItPalette.sun.opacity(0.06),
                            DayForItPalette.ocean.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea(edges: .horizontal)

                    TabView(selection: $selectedPageID) {
                        ForEach(pages) { page in
                            TideTimelinePage(
                                viewData: page,
                                curveHeight: timelineCurveHeight,
                                probe: $probe
                            )
                                .tag(Optional(page.id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .frame(maxWidth: .infinity)
                .frame(height: timelineHeight)

                if let probe {
                    Text("\(time(probe.time)) · \(probe.heightMeters.map { String(format: "%.2f m", $0) } ?? "--")\(probe.isEstimated ? " Est." : "")")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                } else if let note = currentPage.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }
            } else {
                Text("Tide data is loading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .topLeading)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if selectedPageID == nil {
                selectedPageID = pages.first?.id
            }
        }
        .onChange(of: pages.map(\.id)) { _, ids in
            guard let first = ids.first else {
                selectedPageID = nil
                return
            }
            if let selectedPageID, ids.contains(selectedPageID) { return }
            selectedPageID = first
        }
        .onChange(of: selectedPageID) { _, _ in
            probe = nil
        }
    }

    private var currentPage: TideCardViewData? {
        if let selectedPageID, let page = pages.first(where: { $0.id == selectedPageID }) {
            return page
        }
        return pages.first
    }

    private var timelineHeight: CGFloat {
        max(360, availableHeight - 220)
    }

    private var timelineCurveHeight: CGFloat {
        max(280, timelineHeight - 48)
    }

    @ViewBuilder
    private func tidePageSelector(currentPage: TideCardViewData) -> some View {
        HStack(spacing: 7) {
            ForEach(pages) { page in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedPageID = page.id
                    }
                } label: {
                    Text(page.dayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(page.id == currentPage.id ? Color.white : Color.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            Capsule()
                                .fill(page.id == currentPage.id ? DayForItPalette.oceanDeep : DayForItPalette.sky.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func tideInfoColumn(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func eventText(prefix: String, event: TideEventViewPoint?) -> String {
        guard let event else { return "\(prefix) --" }
        if let height = event.heightMeters {
            return "\(time(event.time)) · \(String(format: "%.2f m", height))"
        }
        return time(event.time)
    }

    private func time(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

private struct TideTimelinePage: View {
    let viewData: TideCardViewData
    let curveHeight: CGFloat
    @Binding var probe: TideProbe?

    var body: some View {
        VStack(spacing: 10) {
            InteractiveTideCurveView(viewData: viewData, probe: $probe)
                .frame(height: curveHeight)
            HStack {
                Text(axisLabel(0.0)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(axisLabel(0.25)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(axisLabel(0.5)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(axisLabel(0.75)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(axisLabel(1.0)).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tide curve for \(viewData.dayLabel)")
        .accessibilityValue(accessibilityValue)
    }

    private func axisLabel(_ progress: Double) -> String {
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        let t = start + (end - start) * progress
        return Self.axisFormatter.string(from: Date(timeIntervalSinceReferenceDate: t))
    }

    private static let axisFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    private var accessibilityValue: String {
        var parts = [viewData.stateLabel]
        if let high = viewData.nextHigh {
            parts.append("Next high \(Self.voiceTimeFormatter.string(from: high.time))")
            if let height = high.heightMeters {
                parts.append(String(format: "%.2f metres", height))
            }
        }
        if let low = viewData.nextLow {
            parts.append("Next low \(Self.voiceTimeFormatter.string(from: low.time))")
            if let height = low.heightMeters {
                parts.append(String(format: "%.2f metres", height))
            }
        }
        if let note = viewData.note {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }

    private static let voiceTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

private struct InteractiveTideCurveView: View {
    let viewData: TideCardViewData
    @Binding var probe: TideProbe?
    @State private var probeX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let samples = samplePoints
            let minH = samples.map(\.heightMeters).min() ?? 0
            let maxH = samples.map(\.heightMeters).max() ?? 1
            let span = max(0.001, maxH - minH)
            let now = Date()
            let showsNow = now >= viewData.axisStart && now <= viewData.axisEnd
            let nowX = xPosition(for: now, width: width)

            ZStack {
                ForEach(0 ..< 5) { idx in
                    let x = width * CGFloat(Double(idx) / 4.0)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                if samples.count >= 2 {
                    Path { path in
                        for (idx, sample) in samples.enumerated() {
                            let x = xPosition(for: sample.time, width: width)
                            let y = yPosition(for: sample.heightMeters, min: minH, span: span, height: height)
                            if idx == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(DayForItPalette.oceanDeep.opacity(0.62), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    Path { path in
                        for (idx, sample) in samples.enumerated() {
                            let x = xPosition(for: sample.time, width: width)
                            let y = yPosition(for: sample.heightMeters, min: minH, span: span, height: height)
                            if idx == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(DayForItPalette.ocean.opacity(0.08))

                    ForEach(viewData.events) { event in
                        if let h = event.heightMeters {
                            let x = xPosition(for: event.time, width: width)
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            let isNear = abs((probeX ?? x) - x) < 14
                            Circle()
                                .fill(event.kind == .high ? DayForItPalette.oceanDeep : DayForItPalette.calm)
                                .frame(width: isNear ? 8 : 6, height: isNear ? 8 : 6)
                                .position(x: x, y: y)

                            VStack(spacing: 0) {
                                Text(Self.annotationTimeFormatter.string(from: event.time))
                                    .font(.caption2.weight(.medium))
                                Text(String(format: "%.2f m", h))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .systemBackground).opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .position(
                                x: min(max(48, x), max(48, width - 48)),
                                y: min(max(24, annotationY(for: event.kind, pointY: y)), max(24, height - 24))
                            )
                        }
                    }

                    if probeX == nil, showsNow, let nowProbe = probeAt(x: nowX, width: width, points: samples) {
                        Path { path in
                            path.move(to: CGPoint(x: nowX, y: 0))
                            path.addLine(to: CGPoint(x: nowX, y: height))
                        }
                        .stroke(DayForItPalette.oceanDeep.opacity(0.34), lineWidth: 1)

                        if let h = nowProbe.heightMeters {
                            Circle()
                                .fill(DayForItPalette.oceanDeep)
                                .frame(width: 8, height: 8)
                                .position(
                                    x: nowX,
                                    y: yPosition(for: h, min: minH, span: span, height: height)
                                )
                        }
                    }

                    if let probeX {
                        Path { path in
                            path.move(to: CGPoint(x: probeX, y: 0))
                            path.addLine(to: CGPoint(x: probeX, y: height))
                        }
                        .stroke(Color.primary.opacity(0.30), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

                        if let probe, let h = probe.heightMeters {
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 8)
                                .position(x: probeX, y: y)
                        }
                    }
                } else {
                    Text("Tide curve unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let x = max(0, min(value.location.x, width))
                        withAnimation(.easeOut(duration: 0.18)) {
                            probeX = x
                            probe = probeAt(x: x, width: width, points: samples)
                        }
                    }
            )
        }
    }

    private var samplePoints: [TideSamplePoint] {
        switch viewData.series {
        case let .sampled(points), let .eventInterpolated(points): return points
        case .unavailable: return []
        }
    }

    private func xPosition(for time: Date, width: CGFloat) -> CGFloat {
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        guard end > start else { return 0 }
        let t = min(max(time.timeIntervalSinceReferenceDate, start), end)
        return CGFloat((t - start) / (end - start)) * width
    }

    private func yPosition(for heightValue: Double, min: Double, span: Double, height: CGFloat) -> CGFloat {
        let normalized = (heightValue - min) / span
        return (1 - CGFloat(normalized)) * (height - 10) + 5
    }

    private func annotationY(for kind: TideEventKindView, pointY: CGFloat) -> CGFloat {
        kind == .high ? pointY - 28 : pointY + 28
    }

    private func probeAt(x: CGFloat, width: CGFloat, points: [TideSamplePoint]) -> TideProbe? {
        guard !points.isEmpty, width > 0 else { return nil }
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        guard end > start else { return nil }
        let clampedX = min(max(x, 0), width)
        let t = start + (end - start) * Double(clampedX / width)
        guard let rightIdx = points.firstIndex(where: { $0.time.timeIntervalSinceReferenceDate >= t }) else {
            let p = points.last!
            return TideProbe(time: p.time, heightMeters: p.heightMeters, stateLabel: "Tide prediction", isEstimated: p.isDerived)
        }
        if rightIdx == 0 {
            let p = points[0]
            return TideProbe(time: p.time, heightMeters: p.heightMeters, stateLabel: "Tide prediction", isEstimated: p.isDerived)
        }
        let p0 = points[rightIdx - 1]
        let p1 = points[rightIdx]
        let t0 = p0.time.timeIntervalSinceReferenceDate
        let t1 = p1.time.timeIntervalSinceReferenceDate
        guard t1 > t0 else { return TideProbe(time: p0.time, heightMeters: p0.heightMeters, stateLabel: "Tide prediction", isEstimated: p0.isDerived) }
        let phase = (t - t0) / (t1 - t0)
        let h = p0.heightMeters + (p1.heightMeters - p0.heightMeters) * phase
        return TideProbe(time: Date(timeIntervalSinceReferenceDate: t), heightMeters: h, stateLabel: "Tide prediction", isEstimated: p0.isDerived || p1.isDerived)
    }

    private static let annotationTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

private struct BPDetailedConditionsCard: View {
    let rows: [ConditionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed conditions")
                .font(.headline.weight(.semibold))
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack {
                    Text(row.label).font(.footnote)
                    Spacer()
                    Text(row.value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if idx < rows.count - 1 { Divider().opacity(0.45) }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DayForItPalette.sky.opacity(0.08))
                )
        )
    }
}

private struct BPSourceInfoCard: View {
    let generatedAt: Date?
    let quality: MarineForecastOutput.DataQuality?
    let disclaimer: String

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Source and update")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let generatedAt {
                row("Updated", value: Self.formatter.localizedString(for: generatedAt, relativeTo: Date()))
            }
            row("Data quality", value: quality?.rawValue ?? "Unavailable")
            Text(disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.60))
                .overlay(
                    RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                        .fill(DayForItPalette.sky.opacity(0.10))
                )
        )
        .opacity(0.82)
    }

    @ViewBuilder
    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private enum BPCalmStyle {
    case calm
    case okay
    case notRecommended

    init(rating: BoatDayRating?) {
        switch rating {
        case .green: self = .calm
        case .red: self = .notRecommended
        case .amber, .none: self = .okay
        }
    }

    var tint: Color {
        switch self {
        case .calm: return DayForItPalette.calm
        case .okay: return DayForItPalette.okay
        case .notRecommended: return DayForItPalette.hold
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
