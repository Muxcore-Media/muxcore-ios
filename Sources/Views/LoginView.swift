import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("MuxCore")
                        .font(.largeTitle.bold())
                    Text("Sign in to your media server")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://mux.zem.systems", text: $appState.serverURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    busy = true
                    Task {
                        appState.configureServer(appState.serverURLString)
                        await appState.login()
                        busy = false
                    }
                } label: {
                    HStack {
                        if busy { ProgressView().tint(.white) }
                        Text(busy ? "Signing in…" : "Sign in")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)

                if let error = appState.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                NavigationLink(value: AppRoute.forgotPassword) {
                    Text("Forgot password?")
                        .font(.caption)
                }

                Text("Uses your server’s web login (auth-local). Session cookie is stored on device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
    }
}
