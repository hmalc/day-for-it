import SwiftUI
import WeatherCore
import PleasantnessEngine

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            SummaryTab()
                .tabItem { Label("Summary", systemImage: "sailboat.fill") }
            TidesTab()
                .tabItem { Label("Tides", systemImage: "water.waves") }
        }
        .task { model.startup() }
    }
}

// MARK: - Summary

private struct SummaryTab: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    locationLine

                    if model.isLoading && model.output == nil {
                        SummaryLoadingView()
                    } else {
                        HeroVerdictCard(
                            summary: model.heroOpportunitySummary,
                            windText: model.heroWindText,
                            wavesText: model.heroWavesText,
                            tideText: model.heroTideText,
                            warningText: model.warningBanner
                        )

                        if model.isLoading {
                            RefreshingForecastPill()
                        }

                        ForecastDaysSection(
                            pages: model.fourDayDetailPages,
                            selectedIndex: model.selectedDayIndex,
                            onSelectDay: { model.select(dayIndex: $0) }
                        )

                        sourceFooter
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .refreshable { await model.refresh() }
        }
    }

    private var locationLine: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.caption2)
            Text(model.activeLocationName)
                .font(.subheadline.weight(.medium))
            if let lastUpdatedText = model.lastUpdatedText {
                Text("· \(lastUpdatedText)")
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.lastUpdatedText.map { "\(model.activeLocationName), updated \($0)" } ?? model.activeLocationName)
    }

    @ViewBuilder
    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quality = model.output?.dataQuality {
                Text("Data quality: \(quality.rawValue)")
            }
            Text(model.disclaimer)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

private struct HeroVerdictCard: View {
    let summary: HeroOpportunitySummary
    let windText: String
    let wavesText: String
    let tideText: String
    let warningText: String?

    var body: some View {
        let tint = verdictTint(summary.tone)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ocean Outlook")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    VerdictMeter(verdict: summary.tone, segmentWidth: 8, segmentHeight: 4)
                    Text(summary.badgeText)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
            }

            Text(summary.headline)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.subheadline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(alignment: .top, spacing: 12) {
                signalColumn("Wind", value: windText, systemImage: "wind")
                signalColumn("Waves", value: wavesText, systemImage: "water.waves")
                signalColumn("Tide", value: tideText, systemImage: "arrow.up.and.down")
            }

            if let warningText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(warningText)
                        .font(.footnote)
                        .lineLimit(2)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .groupedCard()
        .animation(.easeInOut(duration: 0.25), value: summary.tone)
    }

    @ViewBuilder
    private func signalColumn(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ForecastDaysSection: View {
    let pages: [FourDayDetailPage]
    let selectedIndex: Int
    let onSelectDay: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle)
                .font(.title3.weight(.semibold))

            if pages.isEmpty {
                Text("Detailed daily forecast is loading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    DaySelectorRow(
                        pages: pages,
                        selectedIndex: selectedIndex,
                        onSelectDay: { sourceIndex in
                            onSelectDay(sourceIndex)
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                proxy.scrollTo(sourceIndex, anchor: .center)
                            }
                        }
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(pages) { page in
                                ForecastDayCard(page: page)
                                    .frame(width: 270)
                                    .id(page.sourceIndex)
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .onTapGesture {
                                        onSelectDay(page.sourceIndex)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(accessibilityLabel(for: page))
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 16)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .padding(.horizontal, -16)
                }
            }
        }
    }

    private var sectionTitle: String {
        if pages.count >= 4 { return "Next 4 Days" }
        if pages.count == 1 { return "Next Forecast Day" }
        return "Next \(pages.count) Forecast Days"
    }

    private func accessibilityLabel(for page: FourDayDetailPage) -> String {
        let verdict = page.verdict?.label ?? "No verdict yet"
        return "\(page.dayLabel), \(verdict). \(page.summaryText)"
    }
}

private struct DaySelectorRow: View {
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
                    VStack(spacing: 5) {
                        Text(compactDayLabel(page.dayLabel))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                        VerdictMeter(verdict: page.verdict, segmentWidth: 7, segmentHeight: 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Color(.tertiarySystemFill) : Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(page.dayLabel), \(page.verdict?.label ?? "no verdict yet")")
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
}

private struct ForecastDayCard: View {
    let page: FourDayDetailPage

    var body: some View {
        let tint = verdictTint(page.verdict)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(page.dayLabel)
                            .font(.headline)
                            .lineLimit(1)
                        if page.isBest {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text(page.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(page.verdict?.label ?? "No call")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    VerdictMeter(verdict: page.verdict, segmentWidth: 10, segmentHeight: 4)
                }
            }

            Text(page.summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !page.topDrivers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(page.topDrivers.prefix(4).enumerated()), id: \.offset) { _, driver in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: tone(for: driver).systemImage)
                                .font(.caption2)
                                .foregroundStyle(tone(for: driver).tint)
                            Text(driver)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                    }
                }
            }

            if let contextText = page.contextText {
                Text(contextText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: page.warningText == "No warnings" ? "checkmark.circle" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text(page.warningText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(page.warningText == "No warnings" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .groupedCard()
    }

    private func tone(for text: String) -> ForecastDriverTone {
        let lower = text.lowercased()
        if lower.contains("no active") {
            return .positive
        }
        if [
            "strong", "fresh winds", "rough", "choppy", "warning",
            "thunderstorm", "squall", "waterspout", "cyclone", "gusting"
        ].contains(where: lower.contains) {
            return .negative
        }
        if [
            "light winds", "gentle winds", "glassy", "low seas", "best current window"
        ].contains(where: lower.contains) {
            return .positive
        }
        return .neutral
    }
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
        case .positive: return .green
        case .neutral: return Color(.systemGray3)
        case .negative: return .orange
        }
    }
}

private struct RefreshingForecastPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text("Refreshing forecast")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
    }
}

private struct SummaryLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking forecast")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LoadingBlock(height: 190)
            LoadingBlock(height: 44)
            LoadingBlock(height: 250)
        }
    }
}

private struct LoadingBlock: View {
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

// MARK: - Tides

private struct TidesTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isLoading && model.tideForecast == nil {
                        TideLoadingView()
                    } else {
                        TidesContent(
                            pages: model.tidePageViewData,
                            statusMessage: model.tideStatusMessage
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tides")
            .refreshable { await model.refresh() }
        }
    }
}

private struct TidesContent: View {
    let pages: [TideCardViewData]
    let statusMessage: String?
    @State private var selectedPageID: Date?
    @State private var probe: TideProbe?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let currentPage {
                Picker("Day", selection: $selectedPageID) {
                    ForEach(pages) { page in
                        Text(page.dayLabel).tag(Optional(page.id))
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(probe?.stateLabel ?? currentPage.stateLabel)
                            .font(.headline)
                        Text(currentPage.windowLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        tideInfoColumn(title: "Next High", value: eventText(event: currentPage.nextHigh))
                        Divider().frame(height: 40)
                        tideInfoColumn(title: "Next Low", value: eventText(event: currentPage.nextLow))
                    }

                    InteractiveTideCurveView(viewData: currentPage, probe: $probe)
                        .frame(height: 300)

                    HStack {
                        ForEach(0 ..< 5) { idx in
                            if idx > 0 { Spacer() }
                            Text(axisLabel(Double(idx) / 4.0, page: currentPage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(probeOrStatusText(for: currentPage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .groupedCard()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tide chart for \(currentPage.dayLabel)")
                .accessibilityValue(accessibilityValue(for: currentPage))
            } else {
                Text("Tide data is loading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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

    private func probeOrStatusText(for page: TideCardViewData) -> String {
        if let probe {
            return "\(time(probe.time)) · \(probe.heightMeters.map { String(format: "%.2f m", $0) } ?? "--")\(probe.isEstimated ? " Est." : "")"
        }
        return statusMessage ?? page.note ?? "Official tide data"
    }

    @ViewBuilder
    private func tideInfoColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventText(event: TideEventViewPoint?) -> String {
        guard let event else { return "--" }
        if let height = event.heightMeters {
            return "\(time(event.time)) · \(String(format: "%.2f m", height))"
        }
        return time(event.time)
    }

    private func axisLabel(_ progress: Double, page: TideCardViewData) -> String {
        let start = page.axisStart.timeIntervalSinceReferenceDate
        let end = page.axisEnd.timeIntervalSinceReferenceDate
        let t = start + (end - start) * progress
        return Self.axisFormatter.string(from: Date(timeIntervalSinceReferenceDate: t))
    }

    private func accessibilityValue(for page: TideCardViewData) -> String {
        var parts = [page.stateLabel]
        if let high = page.nextHigh {
            parts.append("Next high \(time(high.time))")
            if let height = high.heightMeters {
                parts.append(String(format: "%.2f metres", height))
            }
        }
        if let low = page.nextLow {
            parts.append("Next low \(time(low.time))")
            if let height = low.heightMeters {
                parts.append(String(format: "%.2f metres", height))
            }
        }
        if let note = page.note {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }

    private func time(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
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

private struct TideLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading tide data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LoadingBlock(height: 32)
            LoadingBlock(height: 420)
        }
    }
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
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                }

                if samples.count >= 2 {
                    Path { path in
                        for (idx, sample) in samples.enumerated() {
                            let x = xPosition(for: sample.time, width: width)
                            let y = yPosition(for: sample.heightMeters, min: minH, span: span, height: height)
                            if idx == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(.teal, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

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
                    .fill(.teal.opacity(0.10))

                    ForEach(viewData.events) { event in
                        if let h = event.heightMeters {
                            let x = xPosition(for: event.time, width: width)
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            Circle()
                                .fill(.teal)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)

                            VStack(spacing: 0) {
                                Text(Self.annotationTimeFormatter.string(from: event.time))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.2f m", h))
                                    .font(.caption.weight(.semibold))
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemGroupedBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .position(
                                x: min(max(44, x), max(44, width - 44)),
                                y: min(max(20, annotationY(for: event.kind, pointY: y)), max(20, height - 20))
                            )
                        }
                    }

                    if probeX == nil, showsNow, let nowProbe = probeAt(x: nowX, width: width, points: samples) {
                        Path { path in
                            path.move(to: CGPoint(x: nowX, y: 0))
                            path.addLine(to: CGPoint(x: nowX, y: height))
                        }
                        .stroke(Color(.systemGray2), lineWidth: 1)

                        if let h = nowProbe.heightMeters {
                            Circle()
                                .fill(.teal)
                                .stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2)
                                .frame(width: 10, height: 10)
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
                        .stroke(Color(.systemGray), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

                        if let probe, let h = probe.heightMeters {
                            let y = yPosition(for: h, min: minH, span: span, height: height)
                            Circle()
                                .fill(Color(.label))
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
        kind == .high ? pointY - 26 : pointY + 26
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

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
