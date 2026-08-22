import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newName = ""

    var body: some View {
        let playlists = appState.userdata.listPlaylists()
        let favorites = appState.userdata.listFavorites()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("New playlist name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button("Create") {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        let list = playlists + [Playlist(id: UUID().uuidString, name: name, itemIds: [])]
                        appState.userdata.savePlaylists(list)
                        newName = ""
                    }
                }
                if playlists.isEmpty {
                    ContentUnavailableView("No playlists", systemImage: "music.note.list")
                } else {
                    ForEach(playlists) { playlist in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(playlist.name).font(.headline)
                                Spacer()
                                Text("\(playlist.itemIds.count) items").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(playlist.itemIds, id: \.self) { id in
                                if let fav = favorites.first(where: { $0.id == id }) {
                                    Text(fav.title).font(.subheadline)
                                } else {
                                    Text(id).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if !favorites.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(favorites) { fav in
                                            Button("+ \(fav.title)") {
                                                var updated = playlists
                                                if let idx = updated.firstIndex(where: { $0.id == playlist.id }) {
                                                    if !updated[idx].itemIds.contains(fav.id) {
                                                        updated[idx].itemIds.append(fav.id)
                                                        appState.userdata.savePlaylists(updated)
                                                    }
                                                }
                                            }
                                            .font(.caption)
                                            .padding(6)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Playlists")
    }
}
