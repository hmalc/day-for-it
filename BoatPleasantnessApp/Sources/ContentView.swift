import SwiftUI
import WeatherCore
import PleasantnessEngine

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false
    @State private var selectedTab: TopTab = .summary
    @State private var selectedDetailDayIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum TopTab: String, CaseIterable, Identifiable {
        case summary = "Summary"
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
                        let prefersScroll = shouldUseScrollFallback(availableHeight: geo.size.height)
                        if prefersScroll {
                            ScrollView {
                                summaryContent(isSkeleton: model.isLoading && model.output == nil)
                            }
                            .refreshable { await model.refresh() }
                        } else {
                            summaryContent(isSkeleton: model.isLoading && model.output == nil)
                        }
                    }
                } else {
                    if model.isLoading && model.tideForecast == nil {
                        VStack {
                            Spacer()
                            ProgressView("Loading tide data...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ImmersiveTidesView(
                            viewData: model.tideCardViewData,
                            statusMessage: model.tideStatusMessage,
                            nextHighText: model.tideNextHighDisplay,
                            nextLowText: model.tideNextLowDisplay
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Boat Pleasantness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(model.output?.location.name ?? model.effectiveLocation().name)
                            .font(.subheadline.weight(.semibold))
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(model.lastUpdatedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
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
    private func summaryContent(isSkeleton: Bool) -> some View {
        VStack(alignment: .leading, spacing: WeatherSectionLayout.sectionSpacing) {
            if isSkeleton {
                SummarySkeletonView()
            } else {
                FourDayOutlookStrip(items: model.fourDayOutlook) { index in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedDetailDayIndex = index
                    }
                }

                CompactHeroRecommendationCard(
                    tone: model.heroOpportunitySummary.tone,
                    badgeText: model.heroOpportunitySummary.badgeText,
                    headlineText: model.heroOpportunitySummary.headline,
                    summaryText: model.decisionSummaryText,
                    windText: model.heroWindText,
                    wavesText: model.heroWavesText,
                    tideText: model.heroTideText,
                    warningText: model.warningBanner,
                    reduceMotion: reduceMotion
                )

                FourDayDetailPagerCard(
                    pages: model.fourDayDetailPages,
                    selectedIndex: $selectedDetailDayIndex
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func shouldUseScrollFallback(availableHeight: CGFloat) -> Bool {
        dynamicTypeSize.isAccessibilitySize || availableHeight < 760
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
    let reduceMotion: Bool

    var body: some View {
        let style = BPCalmStyle(rating: tone)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Boat outlook", systemImage: "sailboat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(style.tint.opacity(0.2), in: Capsule())
            }

            Text(headlineText)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Text(summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            HStack(spacing: 8) {
                CompactMetricChip(symbol: "wind", label: "Wind", value: windText)
                CompactMetricChip(symbol: "water.waves", label: "Waves", value: wavesText)
                CompactMetricChip(symbol: "arrow.up.and.down", label: "Tide", value: tideText)
            }
            .padding(.top, 8)

            if let warningText, !warningText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(warningText)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 6)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                BPHeroFluid(style: style, reduceMotion: reduceMotion)
                    .clipShape(RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
                RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                    .fill(style.tint.opacity(0.10))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.35), value: tone)
    }
}

private struct CompactMetricChip: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(label, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BPHeroFluid: View {
    let style: BPCalmStyle
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .secondarySystemGroupedBackground), Color(uiColor: .tertiarySystemGroupedBackground)],
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

private struct FourDayOutlookStrip: View {
    let items: [FourDayOutlookItem]
    let onSelectDay: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Next 4 days")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(Array(items.prefix(4).enumerated()), id: \.element.id) { idx, item in
                    VStack(alignment: .center, spacing: 1) {
                        Text(item.dayLabel)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                        Text("\(item.rating.label) \(item.scoreText)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(colorFor(item.rating).opacity(0.16), in: Capsule())
                        if item.hasWarning {
                            Text("Warning")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(item.isBest ? Color.green.opacity(0.08) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectDay(idx)
                    }
                    if idx < min(items.count, 4) - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
        }
    }

    private func colorFor(_ rating: BoatDayRating) -> Color {
        switch rating {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        }
    }
}

private struct FourDayDetailPagerCard: View {
    let pages: [FourDayDetailPage]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("4-day detailed forecast")
                    .font(.headline.weight(.semibold))
                Spacer()
                if pages.indices.contains(selectedIndex) {
                    Text(pages[selectedIndex].dayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)

            if pages.isEmpty {
                Text("Detailed daily forecast is loading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                        DayDetailPageView(page: page, isActive: idx == selectedIndex)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)
                .animation(.easeInOut(duration: 0.3), value: selectedIndex)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == selectedIndex ? Color.primary.opacity(0.8) : Color.primary.opacity(0.25))
                            .frame(width: idx == selectedIndex ? 8 : 6, height: idx == selectedIndex ? 8 : 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
        .onAppear {
            selectedIndex = min(max(0, selectedIndex), max(0, pages.count - 1))
        }
        .onChange(of: pages.count) { _, newCount in
            selectedIndex = min(max(0, selectedIndex), max(0, newCount - 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                        .fill(activeTint.opacity(0.16))
                        .blur(radius: 14)
                }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedIndex)
    }

    private var activeTint: Color {
        guard pages.indices.contains(selectedIndex) else { return .secondary }
        switch pages[selectedIndex].rating {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        }
    }
}

private struct SummarySkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(height: 92)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(height: 178)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
            RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(height: 180)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
            ProgressView("Loading forecast...")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .redacted(reason: .placeholder)
    }
}

private struct DayDetailPageView: View {
    let page: FourDayDetailPage
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.dateText)
                        .font(.subheadline.weight(.semibold))
                    Text("Rating: \(page.rating.label) · Score: \(page.scoreText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(page.warningText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(page.warningText == "No warning constraint" ? Color.green.opacity(0.14) : Color.orange.opacity(0.16), in: Capsule())
            }

            HStack {
                rawMetric(label: "Availability", value: page.availabilityText)
                Spacer()
                rawMetric(label: "Confidence", value: page.confidenceText)
            }

            Divider().opacity(0.4)

            Text("Raw daily drivers")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(page.topDrivers.enumerated()), id: \.offset) { idx, driver in
                Text("\(idx + 1). \(driver)")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(isActive ? 0.60 : 0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    @ViewBuilder
    private func rawMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
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
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct NextChangesCard: View {
    let rows: [NextChangeItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What changes next")
                .font(.headline.weight(.semibold))
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.symbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.body.weight(.medium))
                        Text(row.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
                if idx < rows.count - 1 { Divider().opacity(0.45) }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct TideCard: View {
    let viewData: TideCardViewData
    @State private var probe: TideProbe?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tide")
                .font(.headline.weight(.semibold))
            Text(probe?.stateLabel ?? viewData.stateLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)

            InteractiveTideCurveView(viewData: viewData, probe: $probe)
                .frame(height: 86)

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

            HStack {
                Text("Next high \(viewData.nextHigh.map { time($0.time) } ?? "--")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Next low \(viewData.nextLow.map { time($0.time) } ?? "--")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let probe {
                Text("\(time(probe.time)) · \(probe.heightMeters.map { String(format: "%.2f m", $0) } ?? "--")\(probe.isEstimated ? " Est." : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let note = viewData.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func time(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

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

}

private struct ImmersiveTidesView: View {
    let viewData: TideCardViewData
    let statusMessage: String?
    let nextHighText: String
    let nextLowText: String
    @State private var probe: TideProbe?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tides")
                    .font(.title2.weight(.semibold))
                Text(probe?.stateLabel ?? viewData.stateLabel)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            HStack(alignment: .top, spacing: 12) {
                tideInfoColumn(title: "Next high", value: nextHighText, accent: .blue)
                Divider().frame(height: 52)
                tideInfoColumn(title: "Next low", value: nextLowText, accent: .teal)
            }
            .padding(.horizontal, 20)

            ZStack {
                LinearGradient(
                    colors: [Color.cyan.opacity(0.14), Color.blue.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(edges: .horizontal)

                VStack(spacing: 10) {
                    InteractiveTideCurveView(viewData: viewData, probe: $probe)
                        .frame(height: 410)
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
            }
            .frame(maxWidth: .infinity)

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
            } else if let note = viewData.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .padding(.bottom, 0)
        .ignoresSafeArea(edges: .bottom)
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

    private func time(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func axisLabel(_ progress: Double) -> String {
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        let t = start + (end - start) * progress
        return Self.axisFormatter.string(from: Date(timeIntervalSinceReferenceDate: t))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let axisFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()
}

private struct InteractiveTideCurveView: View {
    let viewData: TideCardViewData
    @Binding var probe: TideProbe?
    @State private var dragX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let samples = samplePoints
            let minH = samples.map(\.heightMeters).min() ?? 0
            let maxH = samples.map(\.heightMeters).max() ?? 1
            let span = max(0.001, maxH - minH)
            let nowX = xPosition(for: Date(), width: width)

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
                    .stroke(Color.cyan.opacity(0.65), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

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
                    .fill(Color.cyan.opacity(0.10))

                    ForEach(viewData.events) { event in
                        if let h = event.heightMeters {
                            let x = xPosition(for: event.time, width: width)
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            let isNear = abs((dragX ?? x) - x) < 14
                            Circle()
                                .fill(event.kind == .high ? Color.blue : Color.teal)
                                .frame(width: isNear ? 8 : 6, height: isNear ? 8 : 6)
                                .position(x: x, y: y)

                            Text(String(format: "%.2f m", h))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(uiColor: .systemBackground).opacity(0.85), in: Capsule())
                                .position(
                                    x: min(max(34, x), max(34, width - 34)),
                                    y: min(max(10, y - 14), max(10, height - 10))
                                )
                        }
                    }

                    if dragX == nil, nowX >= 0, nowX <= width, let nowProbe = probeAt(x: nowX, width: width, points: samples) {
                        Path { path in
                            path.move(to: CGPoint(x: nowX, y: 0))
                            path.addLine(to: CGPoint(x: nowX, y: height))
                        }
                        .stroke(Color.cyan.opacity(0.32), lineWidth: 1)

                        if let h = nowProbe.heightMeters {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 8, height: 8)
                                .position(
                                    x: nowX,
                                    y: yPosition(for: h, min: minH, span: span, height: height)
                                )
                        }
                    }

                    if let dragX {
                        Path { path in
                            path.move(to: CGPoint(x: dragX, y: 0))
                            path.addLine(to: CGPoint(x: dragX, y: height))
                        }
                        .stroke(Color.primary.opacity(0.30), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

                        if let probe, let h = probe.heightMeters {
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 8)
                                .position(x: dragX, y: y)
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(0, min(value.location.x, width))
                        dragX = x
                        probe = probeAt(x: x, width: width, points: samples)
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragX = nil
                            probe = nil
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

    private func probeAt(x: CGFloat, width: CGFloat, points: [TideSamplePoint]) -> TideProbe? {
        guard !points.isEmpty, width > 0 else { return nil }
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        guard end > start else { return nil }
        let clampedX = min(max(x, 0), width)
        let t = start + (end - start) * Double(clampedX / width)
        guard let rightIdx = points.firstIndex(where: { $0.time.timeIntervalSinceReferenceDate >= t }) else {
            let p = points.last!
            return TideProbe(time: p.time, heightMeters: p.heightMeters, stateLabel: "Tide check", isEstimated: p.isDerived)
        }
        if rightIdx == 0 {
            let p = points[0]
            return TideProbe(time: p.time, heightMeters: p.heightMeters, stateLabel: "Tide check", isEstimated: p.isDerived)
        }
        let p0 = points[rightIdx - 1]
        let p1 = points[rightIdx]
        let t0 = p0.time.timeIntervalSinceReferenceDate
        let t1 = p1.time.timeIntervalSinceReferenceDate
        guard t1 > t0 else { return TideProbe(time: p0.time, heightMeters: p0.heightMeters, stateLabel: "Tide check", isEstimated: p0.isDerived) }
        let phase = (t - t0) / (t1 - t0)
        let h = p0.heightMeters + (p1.heightMeters - p0.heightMeters) * phase
        let state = p1.heightMeters >= p0.heightMeters ? "Rising tide" : "Falling tide"
        return TideProbe(time: Date(timeIntervalSinceReferenceDate: t), heightMeters: h, stateLabel: state, isEstimated: p0.isDerived || p1.isDerived)
    }
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
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            row("Updated", value: generatedAt.map { Self.formatter.localizedString(for: $0, relativeTo: Date()) } ?? "Pending")
            row("Data quality", value: quality?.rawValue.capitalized ?? "Unavailable")
            Text(disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: WeatherSectionLayout.cornerRadius, style: .continuous))
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
        case .calm: return Color(red: 0.49, green: 0.70, blue: 0.72)
        case .okay: return Color(red: 0.48, green: 0.62, blue: 0.80)
        case .notRecommended: return Color(red: 0.72, green: 0.43, blue: 0.40)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    if let override = model.savedOverride {
                        Text("Using saved location: \(override.name)")
                        Button("Use default Cowley Beach", role: .destructive) {
                            model.clearLocationOverride()
                        }
                    } else {
                        Text("Using default location: Cowley Beach.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Set manual location") {
                    TextField("Name", text: $name)
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                    Button("Save override") {
                        guard let lat = Double(latitude), let lon = Double(longitude), !name.isEmpty else { return }
                        model.saveLocationOverride(name: name, latitude: lat, longitude: lon)
                    }
                }

                Section("Data") {
                    Button("Refresh now") {
                        Task { await model.refresh() }
                    }
                    Text(model.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
