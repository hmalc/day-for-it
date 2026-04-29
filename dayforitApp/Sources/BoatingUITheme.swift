import SwiftUI
import PleasantnessEngine

enum BoatingUITheme {
    static let horizontalPadding: CGFloat = 20
    static let topSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let heroPadding: CGFloat = 20

    static let heroRadius: CGFloat = 28
    static let metricRadius: CGFloat = 22
    static let sectionRadius: CGFloat = 24
}

enum DayForItPalette {
    static let sky = Color(red: 0.54, green: 0.87, blue: 0.94)
    static let skyDeep = Color(red: 0.22, green: 0.72, blue: 0.88)
    static let ocean = Color(red: 0.09, green: 0.62, blue: 0.76)
    static let oceanDeep = Color(red: 0.04, green: 0.47, blue: 0.64)
    static let sun = Color(red: 1.00, green: 0.86, blue: 0.50)
    static let ink = Color(red: 0.04, green: 0.22, blue: 0.27)
    static let appBackground = Color(red: 0.95, green: 0.985, blue: 0.99)

    static let calm = Color(red: 0.20, green: 0.64, blue: 0.82)
    static let okay = Color(red: 0.38, green: 0.62, blue: 0.74)
    static let caution = Color(red: 0.58, green: 0.64, blue: 0.68)
    static let hold = Color(red: 0.34, green: 0.40, blue: 0.45)

    static var pageBackground: LinearGradient {
        LinearGradient(
            colors: [
                appBackground,
                sky.opacity(0.18),
                Color(uiColor: .systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardWash(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                sky.opacity(0.12),
                sun.opacity(0.035),
                accent.opacity(0.07),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        case let .hero(style):
            content
                .background(
                    RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                                .fill(DayForItPalette.cardWash(accent: style.tint))
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                                .mask(Rectangle().frame(height: 80))
                        }
                )
                .shadow(color: style.tint.opacity(0.08), radius: 7, x: 0, y: 3)
        case .metric:
            content
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: BoatingUITheme.metricRadius, style: .continuous))
        case .section:
            content
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: BoatingUITheme.sectionRadius, style: .continuous))
        }
    }
}

extension View {
    func cardSurface(_ surface: CardSurfaceModifier.Surface) -> some View {
        modifier(CardSurfaceModifier(surface: surface))
    }
}
