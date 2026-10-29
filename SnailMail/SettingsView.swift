import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmReset = false

    var body: some View {
        Form {
            AccountSection()
            Section("viewing as") {
                Picker("demo user", selection: $store.activeProfile) {
                    ForEach(store.profiles) { profile in
                        Text("\(profile.name.lowercased()) · \(profile.city.lowercased())").tag(profile)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("how to test") {
                Text("write a letter as sam, switch to justin, then watch the traveling snail. the dc-to-columbus demo arrives in about one minute")
            }
            Section("feedback") {
                Link("email beat the clock studios", destination: URL(string: "mailto:beattheclockstudios@gmail.com?subject=snail%20mail%20beta%20feedback")!)
                Text("tell us what feels confusing, too cute, too plain, or unexpectedly fun")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("reset demo", role: .destructive) { confirmReset = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("you & the demo")
        .confirmationDialog("delete all demo letters?", isPresented: $confirmReset) {
            Button("reset", role: .destructive) { store.resetDemo() }
        }
    }
}

private struct AccountSection: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmSignOut = false

    var body: some View {
        Section("account") {
            LabeledContent("email", value: auth.email ?? "unknown")
            LabeledContent("status", value: auth.isEmailVerified ? "verified" : "not verified")
            LabeledContent("account id", value: auth.betaCode)
                .textSelection(.enabled)

            if !auth.isEmailVerified {
                Button("resend verification email") {
                    Task { await auth.resendVerification() }
                }
                .disabled(auth.isWorking)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let notice = auth.noticeMessage {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Color.snailGreen)
            }

            Button("sign out", role: .destructive) { confirmSignOut = true }
        }
        .confirmationDialog("sign out of snail mail?", isPresented: $confirmSignOut) {
            Button("sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
        }
    }
}
