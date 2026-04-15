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
        case .calm: return Color(red: 0.49, green: 0.70, blue: 0.72)
        case .okay: return Color(red: 0.48, green: 0.62, blue: 0.80)
        case .caution: return Color(red: 0.78, green: 0.64, blue: 0.42)
        case .notRecommended: return Color(red: 0.72, green: 0.43, blue: 0.40)
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
                                .fill(style.tint.opacity(0.16))
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: BoatingUITheme.heroRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                .mask(Rectangle().frame(height: 80))
                        }
                )
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
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
