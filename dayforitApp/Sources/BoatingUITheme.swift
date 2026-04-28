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
        case .calm: return Color(red: 0.20, green: 0.68, blue: 0.38)
        case .okay: return Color(red: 0.18, green: 0.46, blue: 0.90)
        case .caution: return Color(red: 0.92, green: 0.58, blue: 0.18)
        case .notRecommended: return Color(red: 0.88, green: 0.26, blue: 0.26)
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
                                .fill(style.tint.opacity(0.10))
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
