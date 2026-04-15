import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: BoatingUITheme.sectionSpacing) {
                    HeroRecommendationCard(
                        locationName: model.output?.location.name ?? model.effectiveLocation().name,
                        summary: model.selectedDaySummary,
                        warningText: model.warningBanner,
                        windText: model.heroWindText,
                        wavesText: model.heroWavesText,
                        tideText: model.heroTideText,
                        supporting: model.heroSupportingText
                    )

                    KeyDriversGrid(items: model.keyDriverMetrics)

                    NextChangesCard(rows: model.nextChangeItems)

                    TideCard(
                        summary: model.heroTideText,
                        events: model.tideEvents
                    )

                    DetailedConditionsCard(rows: model.detailedRows)

                    SourceAndUpdateInfoCard(
                        generatedAt: model.output?.generatedAt,
                        quality: model.output?.dataQuality,
                        disclaimer: model.disclaimer
                    )

                    if model.isLoading {
                        ProgressView("Refreshing forecast...")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, BoatingUITheme.horizontalPadding)
                .padding(.top, BoatingUITheme.topSpacing)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(model.output?.location.name ?? "Boat Pleasantness")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(model.output?.location.name ?? "Boat Pleasantness")
                            .font(.headline.weight(.semibold))
                        Text("Updated \(model.lastUpdatedText)")
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
            .refreshable { await model.refresh() }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppModel())
}
