import SwiftUI

struct QuickConnectView: View {
    @EnvironmentObject private var appState: AppState
    @State private var code = ""
    @State private var message: String?
    @State private var ok = false
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField("Code", text: $code)
                    .keyboardType(.numberPad)
                Button(busy ? "Authorizing…" : "Authorize") {
                    Task { await submit() }
                }
                .disabled(busy || code.trimmingCharacters(in: .whitespaces).count < 4)
            } footer: {
                Text("Enter the code shown on your TV or other device.")
            }
            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(ok ? .green : .secondary)
                }
            }
        }
        .navigationTitle("Quick Connect")
    }

    private func submit() async {
        busy = true
        do {
            let msg = try await appState.api.approveQuickConnect(code: code.trimmingCharacters(in: .whitespaces))
            ok = true
            message = msg.isEmpty ? "Code authorized." : msg
        } catch {
            ok = false
            message = error.localizedDescription
        }
        busy = false
    }
}
