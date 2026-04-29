import SwiftUI

struct TideCard: View {
    let summary: String
    let events: [String]

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tide")
                .font(.headline.weight(.semibold))
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TideCurveView(pulse: pulse)
                .frame(height: 92)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }

            HStack {
                ForEach(events.prefix(3), id: \.self) { event in
                    Text(event)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if event != events.prefix(3).last {
                        Spacer()
                    }
                }
            }
        }
        .padding(BoatingUITheme.cardPadding)
        .cardSurface(.section)
    }
}

struct TideCurveView: View {
    let pulse: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h * 0.55

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addCurve(
                        to: CGPoint(x: w, y: midY),
                        control1: CGPoint(x: w * 0.25, y: h * 0.08),
                        control2: CGPoint(x: w * 0.75, y: h * 0.92)
                    )
                }
                .stroke(DayForItPalette.oceanDeep.opacity(0.5), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addCurve(
                        to: CGPoint(x: w, y: midY),
                        control1: CGPoint(x: w * 0.25, y: h * 0.08),
                        control2: CGPoint(x: w * 0.75, y: h * 0.92)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(DayForItPalette.ocean.opacity(0.12))

                Circle()
                    .fill(DayForItPalette.oceanDeep.opacity(0.85))
                    .frame(width: pulse ? 11 : 8, height: pulse ? 11 : 8)
                    .position(x: w * 0.62, y: midY)
                    .shadow(color: DayForItPalette.oceanDeep.opacity(0.35), radius: pulse ? 8 : 3)
            }
        }
    }
}
