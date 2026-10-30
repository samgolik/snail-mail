import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var friendCode = ""
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var personToBlock: SnailProfile?
    @State private var personToReport: SnailProfile?
    @State private var reportReason = ""

    var body: some View {
        Form {
            identitySection
            friendsSection
            accountSection
            Section("feedback") {
                Link(
                    "email beat the clock studios",
                    destination: URL(string: "mailto:beattheclockstudios@gmail.com?subject=snail%20mail%20beta%20feedback")!
                )
                Text("tell us what feels confusing, too cute, too plain, or unexpectedly fun")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("you")
        .refreshable { await store.load() }
        .confirmationDialog("sign out of snail mail?", isPresented: $confirmSignOut) {
            Button("sign out", role: .destructive) {
                store.resetSession()
                Task { await auth.signOut() }
            }
        }
        .alert("delete your account?", isPresented: $confirmDelete) {
            Button("cancel", role: .cancel) {}
            Button("delete forever", role: .destructive) {
                Task {
                    if await store.deleteAccount() {
                        store.resetSession()
                        await auth.signOut()
                    }
                }
            }
        } message: {
            Text("this permanently removes your profile, connections, and every sent or received letter. it cannot be undone.")
        }
        .confirmationDialog(
            "block \(personToBlock?.displayName.lowercased() ?? "this person")?",
            isPresented: Binding(
                get: { personToBlock != nil },
                set: { if !$0 { personToBlock = nil } }
            )
        ) {
            Button("block", role: .destructive) {
                guard let person = personToBlock else { return }
                Task { _ = await store.block(person) }
                personToBlock = nil
            }
        } message: {
            Text("you will no longer be connected or able to exchange letters.")
        }
        .alert(
            "report \(personToReport?.displayName.lowercased() ?? "this person")",
            isPresented: Binding(
                get: { personToReport != nil },
                set: { if !$0 { personToReport = nil } }
            )
        ) {
            TextField("what happened?", text: $reportReason)
            Button("cancel", role: .cancel) {
                personToReport = nil
                reportReason = ""
            }
            Button("send report") {
                guard let person = personToReport else { return }
                let reason = reportReason
                personToReport = nil
                reportReason = ""
                Task { _ = await store.report(person, reason: reason) }
            }
            .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("reports are private and reviewed for safety.")
        }
    }

    private var identitySection: some View {
        Section("your return address") {
            if let profile = store.profile {
                LabeledContent("name", value: profile.displayName.lowercased())
                LabeledContent("handle", value: profile.username.lowercased())
                LabeledContent("city", value: profile.city.lowercased())
                LabeledContent("friend code", value: profile.friendCode)
                    .textSelection(.enabled)
                ShareLink(
                    item: "find me on snail mail with friend code \(profile.friendCode)",
                    subject: Text("my snail mail address")
                ) {
                    Label("share my friend code", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var friendsSection: some View {
        Section("friends") {
            if store.friends.isEmpty {
                Text("no addresses in your book yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.friends) { friend in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(friend.displayName.lowercased())
                            Text(friend.city.lowercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("report", systemImage: "exclamationmark.bubble") {
                                personToReport = friend
                            }
                            Button("block", systemImage: "hand.raised", role: .destructive) {
                                personToBlock = friend
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }

            ForEach(store.incomingRequests) { connection in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(connection.profile.displayName.lowercased()) wants to exchange letters")
                    HStack {
                        Button("accept") {
                            Task { await store.respond(to: connection, accept: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.snailGreen)
                        Button("decline", role: .destructive) {
                            Task { await store.respond(to: connection, accept: false) }
                        }
                    }
                }
            }

            ForEach(store.outgoingRequests) { connection in
                LabeledContent(
                    connection.profile.displayName.lowercased(),
                    value: "request sent"
                )
            }

            TextField("friend code", text: $friendCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("send friend request") {
                Task {
                    if await store.requestFriend(code: friendCode) {
                        friendCode = ""
                    }
                }
            }
            .disabled(friendCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      store.isWorking || !auth.isEmailVerified)

            if !auth.isEmailVerified {
                Text("verify your email before adding friends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var accountSection: some View {
        Section("account") {
            LabeledContent("email", value: auth.email ?? "unknown")
            LabeledContent("status", value: auth.isEmailVerified ? "verified" : "not verified")
            if !auth.isEmailVerified {
                Button("resend verification email") {
                    Task { await auth.resendVerification() }
                }
                .disabled(auth.isWorking)
                Button("i verified my email") {
                    Task { await auth.refreshUser() }
                }
                .disabled(auth.isWorking)
            }
            if let notice = auth.noticeMessage {
                Text(notice).font(.caption).foregroundStyle(Color.snailGreen)
            }
            Button("sign out") { confirmSignOut = true }
            Button("delete account", role: .destructive) { confirmDelete = true }
        }
    }
}
