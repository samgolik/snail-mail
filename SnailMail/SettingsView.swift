import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var friendCode = ""
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var personToBlock: SnailProfile?
    @State private var personToRemove: SnailProfile?
    @State private var personToReport: SnailProfile?
    @State private var reportReason = ""
    @State private var showingProfileEditor = false

    var body: some View {
        Form {
            identitySection
            friendsSection
            blockedSection
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
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("you")
        .refreshable { await store.load() }
        .sheet(isPresented: $showingProfileEditor) {
            if let profile = store.profile {
                ProfileEditorView(profile: profile)
            }
        }
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
        .confirmationDialog(
            "remove \(personToRemove?.displayName.lowercased() ?? "this friend")?",
            isPresented: Binding(
                get: { personToRemove != nil },
                set: { if !$0 { personToRemove = nil } }
            )
        ) {
            Button("remove connection", role: .destructive) {
                guard let person = personToRemove else { return }
                Task { _ = await store.removeFriend(person) }
                personToRemove = nil
            }
        } message: {
            Text("old letters stay in both mailboxes. either person can send a new request later.")
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
                if let friendCode = profile.friendCode, !friendCode.isEmpty {
                    LabeledContent("friend code", value: friendCode)
                        .textSelection(.enabled)
                    ShareLink(
                        item: "find me on snail mail with friend code \(friendCode)",
                        subject: Text("my snail mail address")
                    ) {
                        Label("share my friend code", systemImage: "square.and.arrow.up")
                    }
                }
                Button("edit return address", systemImage: "pencil") {
                    showingProfileEditor = true
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
                            Button("remove friend", systemImage: "person.badge.minus", role: .destructive) {
                                personToRemove = friend
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
                      store.isWorking || !auth.isPhoneVerified)

            if !auth.isPhoneVerified {
                Text("verify your phone before adding friends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var blockedSection: some View {
        if !store.blockedProfiles.isEmpty {
            Section("blocked accounts") {
                ForEach(store.blockedProfiles) { person in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(person.displayName.lowercased())
                            Text(person.username.lowercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("unblock") {
                            Task { _ = await store.unblock(person) }
                        }
                        .disabled(store.isWorking)
                    }
                }
                Text("unblocking does not restore the old connection. exchange a new friend request when you are ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accountSection: some View {
        Section("account") {
            LabeledContent("phone", value: auth.phoneNumber ?? "unknown")
            Text("your verified phone number is your sign-in. it is never shown to friends.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let notice = auth.noticeMessage {
                Text(notice).font(.caption).foregroundStyle(Color.snailGreen)
            }
            Button("sign out") { confirmSignOut = true }
            Button("delete account", role: .destructive) { confirmDelete = true }
            Link("privacy policy", destination: URL(string: "https://snail-mail-btc.web.app/privacy")!)
            Link("terms of use", destination: URL(string: "https://snail-mail-btc.web.app/terms")!)
            Link("community guidelines", destination: URL(string: "https://snail-mail-btc.web.app/community")!)
            Link("support", destination: URL(string: "https://snail-mail-btc.web.app/support")!)
            LabeledContent("version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
private struct ProfileEditorView: View {
    @EnvironmentObject private var store: ProductionStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var username: String
    @State private var city: String
    @State private var isLocating = false

    init(profile: SnailProfile) {
        _displayName = State(initialValue: profile.displayName)
        _username = State(initialValue: profile.username.replacingOccurrences(of: "@", with: ""))
        _city = State(initialValue: profile.city)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("your return address") {
                    TextField("name", text: $displayName)
                        .textContentType(.name)
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("city, state", text: $city)
                        .textContentType(.addressCity)
                }
                Section {
                    Text("your city is converted to approximate coordinates for delivery timing. exact device location is never requested.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = store.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(PastelBackground())
            .navigationTitle("edit address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { Task { await save() } }
                        .disabled(!canSave || store.isWorking || isLocating)
                }
            }
            .interactiveDismissDisabled(store.isWorking || isLocating)
        }
        .tint(.snailGreen)
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let resolvedCity = try await CityResolver.resolve(city)
            if await store.saveProfile(
                displayName: displayName,
                username: username,
                city: resolvedCity.name,
                latitude: resolvedCity.latitude,
                longitude: resolvedCity.longitude
            ) {
                dismiss()
            }
        } catch {
            store.errorMessage = "we couldn’t find that city — try “city, state”"
        }
    }
}
