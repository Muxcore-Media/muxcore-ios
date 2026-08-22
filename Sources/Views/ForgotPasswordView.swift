import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var appState: AppState
    @State private var username = ""
    @State private var note = ""
    @State private var message: String?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Message (optional)", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                Button(busy ? "Submitting…" : "Submit request") {
                    Task { await submit() }
                }
                .disabled(busy || username.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Your administrator will reset your password.")
            }
            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Forgot password")
    }

    private func submit() async {
        busy = true
        error = nil
        message = nil
        do {
            message = try await appState.api.requestPasswordReset(
                username: username.trimmingCharacters(in: .whitespaces),
                note: note.trimmingCharacters(in: .whitespaces)
            )
            username = ""
            note = ""
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
