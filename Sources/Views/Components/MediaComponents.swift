import SwiftUI

struct PosterImage: View {
    let urlString: String
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}

struct MediaCard: View {
    let title: String
    let posterURL: String
    let subtitle: String?
    let ready: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                PosterImage(urlString: posterURL, cornerRadius: 10)
                    .frame(width: 120, height: 180)
                if ready {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(6)
                }
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120)
    }
}

struct PosterGrid<Content: View>: View {
    let columns: [GridItem]
    @ViewBuilder let content: () -> Content

    init(columns: Int = 3, @ViewBuilder content: @escaping () -> Content) {
        self.columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
    }
}

struct ShelfSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
            }
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct ErrorStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding()
    }
}
