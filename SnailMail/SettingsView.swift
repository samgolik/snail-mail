import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmReset = false

    var body: some View {
        Form {
            BetaAccountSection()
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

private struct BetaAccountSection: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AccountMode = .create
    @State private var showForm = false

    var body: some View {
        Section("beta account") {
            LabeledContent("status", value: status)
            LabeledContent("beta id", value: auth.betaCode)
                .textSelection(.enabled)

            if auth.isAnonymous {
                Text("your demo is connected privately. save it with an email when you want to use the same account on another phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(showForm ? "hide account setup" : "save or restore account") {
                    withAnimation { showForm.toggle() }
                }
                if showForm { accountForm }
            } else {
                Text(auth.email ?? "saved account")
                    .foregroundStyle(.secondary)
                Button("sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }

            if auth.isWorking {
                ProgressView("connecting...")
            }
            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var status: String {
        guard auth.user != nil else { return "connecting" }
        return auth.isAnonymous ? "guest" : "saved"
    }

    private var accountForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("account action", selection: $mode) {
                ForEach(AccountMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            TextField("email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            SecureField("password", text: $password)
            Button(mode.buttonLabel) {
                Task {
                    let success = mode == .create
                        ? await auth.createAccount(email: email, password: password)
                        : await auth.signIn(email: email, password: password)
                    if success {
                        password = ""
                        showForm = false
                    }
                }
            }
            .disabled(email.isEmpty || password.count < 6 || auth.isWorking)
        }
    }
}

private enum AccountMode: String, CaseIterable, Identifiable {
    case create
    case signIn

    var id: Self { self }
    var label: String { self == .create ? "save" : "sign in" }
    var buttonLabel: String { self == .create ? "save this account" : "sign in" }
}
