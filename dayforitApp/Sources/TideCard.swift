import SwiftUI

struct TideCard: View {
    let pages: [TideCardViewData]
    var isEmbedded = false
    var selectedPageIndex: Int? = nil

    @State private var selectedPageID: Date?

    var body: some View {
        Group {
            if isEmbedded {
                content
            } else {
                content
                    .padding(BoatingUITheme.cardPadding)
                    .cardSurface(.section)
            }
        }
        .onAppear {
            guard selectedPageIndex == nil else { return }
            if selectedPageID == nil {
                selectedPageID = pages.first?.id
            }
        }
        .onChange(of: pages.map(\.id)) { _, ids in
            guard selectedPageIndex == nil else { return }
            guard let first = ids.first else {
                selectedPageID = nil
                return
            }
            if let selectedPageID, ids.contains(selectedPageID) { return }
            selectedPageID = first
        }
    }

    private var content: some View {
        let page = selectedPage
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("Tide", systemImage: "arrow.up.and.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DayForItPalette.oceanDeep)
                Spacer()
                Text(statusText(for: page))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if !pages.isEmpty {
                if !isEmbedded {
                    tideTabs
                }

                if let page {
                    MiniTideCurveView(viewData: page)
                        .frame(height: 116)

                    tideEventList(for: page)

                    if let note = page.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                }
            } else {
                Text("Official tide data unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var selectedPage: TideCardViewData? {
        if let selectedPageIndex, !pages.isEmpty {
            let boundedIndex = min(max(selectedPageIndex, 0), pages.count - 1)
            return pages[boundedIndex]
        }
        if let selectedPageID, let match = pages.first(where: { $0.id == selectedPageID }) {
            return match
        }
        return pages.first
    }

    private func statusText(for page: TideCardViewData?) -> String {
        guard let page else { return "Tide data unavailable" }
        return isEmbedded ? "\(page.dayLabel) · \(page.stateLabel)" : page.stateLabel
    }

    private var tideTabs: some View {
        HStack(spacing: 7) {
            ForEach(pages) { page in
                let isSelected = page.id == selectedPage?.id
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedPageID = page.id
                    }
                } label: {
                    Text(page.dayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? DayForItPalette.onAccent : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            Capsule()
                                .fill(isSelected ? DayForItPalette.oceanDeep : DayForItPalette.insetBackground)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.clear : DayForItPalette.hairline, lineWidth: 0.7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show tides for \(page.dayLabel)")
            }
        }
    }

    @ViewBuilder
    private func tideEventList(for page: TideCardViewData) -> some View {
        let events = eventsInWindow(for: page)
        if events.isEmpty {
            Text("No highs or lows in this calendar day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DayForItPalette.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            LazyVGrid(columns: eventGridColumns, alignment: .leading, spacing: 8) {
                ForEach(events) { event in
                    tideEventChip(event)
                }
            }
        }
    }

    private var eventGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    private func tideEventChip(_ event: TideEventViewPoint) -> some View {
        let isHigh = event.kind == .high
        let accent = isHigh ? DayForItPalette.oceanDeep : DayForItPalette.calm
        return HStack(spacing: 8) {
            Image(systemName: isHigh ? "arrow.up" : "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .background(accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(isHigh ? "High" : "Low")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                Text(eventText(event))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DayForItPalette.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DayForItPalette.hairline, lineWidth: 0.7)
        )
    }

    private func eventsInWindow(for page: TideCardViewData) -> [TideEventViewPoint] {
        page.events
            .filter { $0.time >= page.axisStart && $0.time < page.axisEnd }
            .sorted { $0.time < $1.time }
    }

    private func eventText(_ event: TideEventViewPoint) -> String {
        let time = Self.timeFormatter.string(from: event.time)
        if let height = event.heightMeters {
            return "\(time) · \(String(format: "%.2f m", height))"
        }
        return time
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()
}

private struct MiniTideCurveView: View {
    let viewData: TideCardViewData

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let points = samplePoints
            let axisMinimum = 0.0
            let axisMaximum = max(1.0, viewData.chartMaximumMeters)
            let span = max(0.001, axisMaximum - axisMinimum)
            let now = Date()
            let showsNow = now >= viewData.axisStart && now < viewData.axisEnd

            ZStack {
                scaleGuide(width: width, height: height, axisMaximum: axisMaximum)

                if points.count >= 2 {
                    tideFill(points: points, width: width, height: height, minHeight: axisMinimum, span: span)
                    tideLine(points: points, width: width, height: height, minHeight: axisMinimum, span: span)

                    ForEach(eventsInWindow) { event in
                        if let eventHeight = event.heightMeters {
                            let pointX = xPosition(for: event.time, width: width)
                            let pointY = yPosition(for: eventHeight, minHeight: axisMinimum, span: span, height: height)
                            MiniTideEventMarker(
                                event: event,
                                x: pointX,
                                y: pointY,
                                chartWidth: width,
                                chartHeight: height
                            )
                        }
                    }

                    if showsNow, let nowHeight = interpolatedHeight(at: now, in: points) {
                        TideNowMarker(
                            x: xPosition(for: now, width: width),
                            y: yPosition(for: nowHeight, minHeight: axisMinimum, span: span, height: height),
                            chartWidth: width,
                            chartHeight: height
                        )
                    }
                } else {
                    fallbackCurve(width: width, height: height)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tide curve for \(viewData.dayLabel)")
            .accessibilityValue(viewData.stateLabel)
        }
    }

    private var samplePoints: [TideSamplePoint] {
        switch viewData.series {
        case let .sampled(points), let .eventInterpolated(points):
            return points
        case .unavailable:
            return []
        }
    }

    private var eventsInWindow: [TideEventViewPoint] {
        viewData.events
            .filter { $0.time >= viewData.axisStart && $0.time < viewData.axisEnd }
            .sorted { $0.time < $1.time }
    }

    private func scaleGuide(width: CGFloat, height: CGFloat, axisMaximum: Double) -> some View {
        ZStack {
            ForEach([0.0, 0.5, 1.0], id: \.self) { progress in
                let y = plotBottom(for: height) - CGFloat(progress) * plotHeight(for: height)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(DayForItPalette.hairline.opacity(progress == 0 ? 0.7 : 0.38), lineWidth: 0.7)
            }

            VStack(alignment: .trailing) {
                Text(String(format: "%.1fm", axisMaximum))
                Spacer()
                Text("0m")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.secondary.opacity(0.82))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
    }

    private func tideLine(points: [TideSamplePoint], width: CGFloat, height: CGFloat, minHeight: Double, span: Double) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let xy = CGPoint(
                    x: xPosition(for: point.time, width: width),
                    y: yPosition(for: point.heightMeters, minHeight: minHeight, span: span, height: height)
                )
                if index == 0 {
                    path.move(to: xy)
                } else {
                    path.addLine(to: xy)
                }
            }
        }
        .stroke(DayForItPalette.oceanDeep.opacity(0.72), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
    }

    private func tideFill(points: [TideSamplePoint], width: CGFloat, height: CGFloat, minHeight: Double, span: Double) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let xy = CGPoint(
                    x: xPosition(for: point.time, width: width),
                    y: yPosition(for: point.heightMeters, minHeight: minHeight, span: span, height: height)
                )
                if index == 0 {
                    path.move(to: xy)
                } else {
                    path.addLine(to: xy)
                }
            }
            let bottom = plotBottom(for: height)
            path.addLine(to: CGPoint(x: width, y: bottom))
            path.addLine(to: CGPoint(x: 0, y: bottom))
            path.closeSubpath()
        }
        .fill(DayForItPalette.ocean.opacity(0.10))
    }

    private func fallbackCurve(width: CGFloat, height: CGFloat) -> some View {
        let midY = height * 0.55
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: midY))
                path.addCurve(
                    to: CGPoint(x: width, y: midY),
                    control1: CGPoint(x: width * 0.25, y: height * 0.08),
                    control2: CGPoint(x: width * 0.75, y: height * 0.92)
                )
            }
            .stroke(DayForItPalette.oceanDeep.opacity(0.5), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }

    private func xPosition(for time: Date, width: CGFloat) -> CGFloat {
        let start = viewData.axisStart.timeIntervalSinceReferenceDate
        let end = viewData.axisEnd.timeIntervalSinceReferenceDate
        guard end > start else { return 0 }
        let clamped = min(max(time.timeIntervalSinceReferenceDate, start), end)
        return CGFloat((clamped - start) / (end - start)) * width
    }

    private func yPosition(for value: Double, minHeight: Double, span: Double, height: CGFloat) -> CGFloat {
        let normalized = min(max((value - minHeight) / span, 0), 1)
        return plotBottom(for: height) - CGFloat(normalized) * plotHeight(for: height)
    }

    private func interpolatedHeight(at time: Date, in points: [TideSamplePoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        let target = time.timeIntervalSinceReferenceDate
        guard let rightIndex = points.firstIndex(where: { $0.time.timeIntervalSinceReferenceDate >= target }) else {
            return points.last?.heightMeters
        }
        if rightIndex == 0 {
            return points.first?.heightMeters
        }
        let left = points[rightIndex - 1]
        let right = points[rightIndex]
        let leftTime = left.time.timeIntervalSinceReferenceDate
        let rightTime = right.time.timeIntervalSinceReferenceDate
        guard rightTime > leftTime else { return left.heightMeters }
        let phase = (target - leftTime) / (rightTime - leftTime)
        return left.heightMeters + (right.heightMeters - left.heightMeters) * phase
    }

    private func plotTop(for height: CGFloat) -> CGFloat {
        max(8, height * 0.08)
    }

    private func plotBottom(for height: CGFloat) -> CGFloat {
        max(plotTop(for: height) + 1, height - max(12, height * 0.12))
    }

    private func plotHeight(for height: CGFloat) -> CGFloat {
        plotBottom(for: height) - plotTop(for: height)
    }
}

private struct MiniTideEventMarker: View {
    let event: TideEventViewPoint
    let x: CGFloat
    let y: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat

    private var isHigh: Bool { event.kind == .high }
    private var accent: Color { isHigh ? DayForItPalette.oceanDeep : DayForItPalette.calm }

    var body: some View {
        ZStack {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .position(x: x, y: y)

            annotation
        }
    }

    private var annotation: some View {
        let labelWidth: CGFloat = 58
        let yOffset: CGFloat = isHigh ? -18 : 20
        return VStack(spacing: 0) {
            Text("\(isHigh ? "H" : "L") \(Self.timeFormatter.string(from: event.time))")
                .font(.system(size: 9, weight: .semibold))
            Text(event.heightMeters.map { String(format: "%.2fm", $0) } ?? "--")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(width: labelWidth)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .position(
            x: Swift.min(Swift.max(labelWidth / 2, x), Swift.max(labelWidth / 2, chartWidth - labelWidth / 2)),
            y: Swift.min(Swift.max(18, y + yOffset), Swift.max(18, chartHeight - 18))
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()
}

struct TideNowMarker: View {
    let x: CGFloat
    let y: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: chartHeight))
            }
            .stroke(DayForItPalette.sun.opacity(0.58), style: StrokeStyle(lineWidth: 1.1, dash: [3, 4]))

            Circle()
                .fill(DayForItPalette.sun.opacity(0.28))
                .frame(width: 18, height: 18)
                .scaleEffect(isPulsing ? 1.75 : 0.72)
                .opacity(isPulsing ? 0.05 : 0.72)
                .position(x: x, y: y)

            Circle()
                .fill(DayForItPalette.sun)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                )
                .shadow(color: DayForItPalette.sun.opacity(0.35), radius: 5, x: 0, y: 1)
                .position(x: x, y: y)
        }
        .frame(width: chartWidth, height: chartHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isPulsing = false
            withAnimation(.easeOut(duration: 1.35).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
