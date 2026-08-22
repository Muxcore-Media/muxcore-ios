import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var appState: AppState
    @State private var playerItem: PlayerItem?

    private var displayQueue: [QueueItem] {
        let queue = appState.userdata.listQueue()
        if !queue.isEmpty { return queue }
        let fromProgress = appState.userdata.continueWatching(20).compactMap { p -> QueueItem? in
            guard let href = PlayHref.progressPlayer(p) else { return nil }
            return QueueItem(id: p.id, kind: p.kind, title: p.title, href: href, streamURL: p.streamURL, posterURL: p.posterURL)
        }
        let fromFav = appState.userdata.listFavorites().prefix(20).map { f in
            QueueItem(id: f.id, kind: f.kind, title: f.title, href: f.href, posterURL: f.posterURL)
        }
        return fromProgress + fromFav
    }

    var body: some View {
        List {
            if displayQueue.isEmpty {
                ContentUnavailableView("Queue empty", systemImage: "list.bullet", description: Text("Play something or add favorites."))
            } else {
                ForEach(Array(displayQueue.enumerated()), id: \.offset) { index, item in
                    HStack {
                        if let poster = item.posterURL {
                            PosterImage(urlString: poster, cornerRadius: 4)
                                .frame(width: 40, height: 60)
                        }
                        VStack(alignment: .leading) {
                            Text("\(index + 1). \(item.title)")
                                .font(.subheadline.weight(.semibold))
                            Text(item.kind.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let stream = item.streamURL, !stream.isEmpty {
                            Button {
                                playerItem = PlayerItem(id: item.id, title: item.title, streamPath: stream, posterURL: item.posterURL, kind: item.kind.rawValue)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                            }
                        }
                        if appState.userdata.listQueue().contains(where: { $0.id == item.id }) {
                            Button {
                                appState.userdata.dequeue(id: item.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Queue")
        .toolbar {
            if !appState.userdata.listQueue().isEmpty {
                Button("Clear") { appState.userdata.clearQueue() }
            }
        }
        .fullScreenCover(item: $playerItem) { PlayerView(item: $0) }
    }
}
