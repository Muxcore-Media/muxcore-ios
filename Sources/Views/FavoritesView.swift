import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState

    private var favorites: [FavoriteEntry] {
        appState.userdata.listFavorites()
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No favorites",
                    systemImage: "heart",
                    description: Text("Use the star on a detail page.")
                )
            } else {
                ScrollView {
                    PosterGrid {
                        ForEach(favorites, id: \.id) { fav in
                            favoriteLink(for: fav)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favorites")
    }

    @ViewBuilder
    private func favoriteLink(for fav: FavoriteEntry) -> some View {
        let route: AppRoute = fav.kind == .tv ? .tvShow(fav.id) : .movie(fav.id)
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 6) {
                PosterImage(urlString: fav.posterURL ?? "", cornerRadius: 10)
                    .frame(height: 160)
                Text(fav.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }
        }
    }
}
