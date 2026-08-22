import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let items = appState.userdata.listFavorites()
        ScrollView {
            if items.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "heart", description: Text("Use the star on a detail page."))
                    .padding()
            } else {
                PosterGrid {
                    ForEach(items, id: \.id) { fav in
                        NavigationLink(value: fav.kind == .tv ? AppRoute.tvShow(fav.id) : AppRoute.movie(fav.id)) {
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
                .padding()
            }
        }
        .navigationTitle("Favorites")
    }
}
