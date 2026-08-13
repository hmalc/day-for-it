import SwiftUI
import PleasantnessEngine

enum BoatingUITheme {
    static let horizontalPadding: CGFloat = 20
    static let topSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let heroPadding: CGFloat = 20

    static let heroRadius: CGFloat = 20
    static let metricRadius: CGFloat = 16
    static let sectionRadius: CGFloat = 18
}

enum DayForItPalette {
    static let sky = adaptiveColor(
        light: (0.73, 0.88, 1.00),
        dark: (0.20, 0.38, 0.55)
    )
    static let skyDeep = adaptiveColor(
        light: (0.12, 0.45, 0.92),
        dark: (0.28, 0.62, 1.00)
    )
    static let ocean = adaptiveColor(
        light: (0.17, 0.52, 0.82),
        dark: (0.20, 0.58, 0.88)
    )
    static let oceanDeep = adaptiveColor(
        light: (0.08, 0.36, 0.62),
        dark: (0.20, 0.56, 0.92)
    )
    static let sun = adaptiveColor(
        light: (0.92, 0.46, 0.08),
        dark: (1.00, 0.64, 0.25)
    )
    static let ink = Color.primary
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let insetBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let hairline = Color.primary.opacity(0.08)
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })
    static let elevatedShadow = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.22)
            : UIColor.black.withAlphaComponent(0.055)
    })
    static let shimmerHighlight = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.16)
            : UIColor.white.withAlphaComponent(0.42)
    })

    static let calm = skyDeep
    static let okay = sun
    static let caution = Color(uiColor: .systemOrange)
    static let hold = Color(uiColor: .systemRed)

    static var pageBackground: Color {
        appBackground
    }

    static func cardWash(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                .clear,
                accent.opacity(0.035),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptiveColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let values = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(values.0),
                green: CGFloat(values.1),
                blue: CGFloat(values.2),
                alpha: 1
            )
        })
    }
}

enum CalmnessVisualStyle {
    case calm
    case okay
    case caution
    case notRecommended

    init(rating: BoatDayRating?) {
        switch rating {
        case .green: self = .calm
        case .amber, .none: self = .okay
        case .red: self = .notRecommended
        }
    }

    var tint: Color {
        switch self {
        case .calm: return DayForItPalette.calm
        case .okay: return DayForItPalette.okay
        case .caution: return DayForItPalette.caution
        case .notRecommended: return DayForItPalette.hold
        }
    }
}

struct CardSurfaceModifier: ViewModifier {
    enum Surface {
        case hero(CalmnessVisualStyle)
        case metric
        case section
    }

    let surface: Surface

    func body(content: Content) -> some View {
        switch surface {
        case .hero:
            content
                .background(
                    RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                        .fill(DayForItPalette.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                                .strokeBorder(DayForItPalette.hairline, lineWidth: 0.7)
                        )
                )
                .shadow(color: DayForItPalette.elevatedShadow, radius: 8, x: 0, y: 4)
        case .metric:
            content
                .background(DayForItPalette.cardBackground, in: RoundedRectangle(cornerRadius: BoatingUITheme.metricRadius, style: .continuous))
        case .section:
            content
                .background(DayForItPalette.cardBackground, in: RoundedRectangle(cornerRadius: BoatingUITheme.sectionRadius, style: .continuous))
        }
    }
}

extension View {
    func cardSurface(_ surface: CardSurfaceModifier.Surface) -> some View {
        modifier(CardSurfaceModifier(surface: surface))
    }
}
