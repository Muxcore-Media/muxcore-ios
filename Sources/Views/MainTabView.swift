import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            tabStack(icon: "house.fill", title: "Home") { HomeView() }
            tabStack(icon: "magnifyingglass", title: "Search") { SearchView() }
            if appState.capabilities.libraryEnabled("movies") {
                tabStack(icon: "film.fill", title: "Movies") { MoviesView() }
            }
            tabStack(icon: "ellipsis.circle.fill", title: "More") { MoreView() }
        }
    }

    @ViewBuilder
    private func tabStack(icon: String, title: String, @ViewBuilder content: () -> some View) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: Movie.self) { MovieDetailView(movieID: $0.id) }
                .navigationDestination(for: TVShow.self) { TVShowDetailView(showID: $0.id) }
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
        .tabItem { Label(title, systemImage: icon) }
    }
}
