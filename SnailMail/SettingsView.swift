import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var showingProfileEditor = false

    var body: some View {
        Form {
            identitySection
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
    }

    private var identitySection: some View {
        Section("your home snailbox") {
            if let profile = store.profile {
                LabeledContent("name", value: profile.displayName.lowercased())
                LabeledContent("handle", value: profile.username.lowercased())
                LabeledContent("city", value: profile.city.lowercased())
                Button("edit snailing address", systemImage: "pencil") {
                    showingProfileEditor = true
                }
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
            Link("privacy policy", destination: SnailLinks.page("privacy"))
            Link("terms of use", destination: SnailLinks.page("terms"))
            Link("community guidelines", destination: SnailLinks.page("community"))
            Link("support", destination: SnailLinks.page("support"))
            LabeledContent("version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct AddressBookView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var identifier = ""
    @State private var requestSent = false
    @State private var personToRemove: SnailProfile?
    @State private var personToBlock: SnailProfile?
    @State private var personToReport: SnailProfile?
    @State private var reportReason = ""
    @State private var didSearch = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    TextField("search usernames", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { search() }
                    Button {
                        search()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(!canSearch)
                    .accessibilityLabel("search usernames")
                }
                Text("type at least two characters. only usernames are searched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let username = store.profile?.username,
                   let inviteURL = inviteURL(for: username) {
                    ShareLink(
                        item: inviteURL,
                        subject: Text("my snailing address"),
                        message: Text("send me a slow note on snail mail — my snailing address is \(username)")
                    ) {
                        Label("invite a friend", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.snailGreen)
                    Text("share a link by text or any app. they can find your snailing address in one tap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("find a friend")
            }

            if !store.friendSearchResults.isEmpty {
                Section("people") {
                    ForEach(store.friendSearchResults) { person in
                        HStack {
                            addressLabel(person)
                            Spacer()
                            Button("add") { sendRequest(to: person) }
                                .buttonStyle(.bordered)
                                .disabled(store.isWorking)
                        }
                    }
                }
            } else if didSearch && store.errorMessage == nil {
                Section {
                    ContentUnavailableView(
                        "no usernames found",
                        systemImage: "magnifyingglass",
                        description: Text("try a nearby spelling or fewer letters")
                    )
                }
            }

            if !store.incomingRequests.isEmpty {
                Section("requests for you") {
                    ForEach(store.incomingRequests) { connection in
                        VStack(alignment: .leading, spacing: 10) {
                            addressLabel(connection.profile)
                            HStack {
                                Button("accept") {
                                    Task { await store.respond(to: connection, accept: true) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.snailGreen)
                                .disabled(store.isWorking)
                                Button("decline", role: .destructive) {
                                    Task { await store.respond(to: connection, accept: false) }
                                }
                                .disabled(store.isWorking)
                            }
                        }
                    }
                }
            }

            if !store.outgoingRequests.isEmpty {
                Section("waiting for a reply") {
                    ForEach(store.outgoingRequests) { connection in
                        LabeledContent {
                            Text("sent").foregroundStyle(.secondary)
                        } label: {
                            addressLabel(connection.profile)
                        }
                    }
                }
            }

            Section("your snailing addresses") {
                if store.friends.isEmpty {
                    ContentUnavailableView(
                        "no snailing addresses yet",
                        systemImage: "book.closed",
                        description: Text("add a friend above to begin exchanging letters")
                    )
                } else {
                    ForEach(store.friends) { friend in
                        HStack {
                            addressLabel(friend)
                            Spacer()
                            Menu {
                                Button("report", systemImage: "exclamationmark.bubble") {
                                    personToReport = friend
                                }
                                Button("block", systemImage: "hand.raised", role: .destructive) {
                                    personToBlock = friend
                                }
                                Button("remove snailing address", systemImage: "person.badge.minus", role: .destructive) {
                                    personToRemove = friend
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }

            if let error = store.errorMessage {
                Section { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .navigationTitle("friends")
        .refreshable { await store.load() }
        .onAppear { applyPendingInvite() }
        .onChange(of: store.pendingFriendHandle) { _, _ in
            applyPendingInvite()
        }
        .alert("request sent", isPresented: $requestSent) {
            Button("lovely", role: .cancel) {}
        } message: {
            Text("their snailing address will appear here as soon as they accept.")
        }
        .confirmationDialog(
            "remove \(personToRemove?.displayName.lowercased() ?? "this snailing address")?",
            isPresented: Binding(
                get: { personToRemove != nil },
                set: { if !$0 { personToRemove = nil } }
            )
        ) {
            Button("remove", role: .destructive) {
                guard let person = personToRemove else { return }
                personToRemove = nil
                Task { _ = await store.removeFriend(person) }
            }
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
                personToBlock = nil
                Task { _ = await store.block(person) }
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

    private var canSearch: Bool {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "").count >= 2 &&
        !store.isWorking && auth.isPhoneVerified
    }

    private func inviteURL(for username: String) -> URL? {
        SnailLinks.friendInvite(handle: username)
    }

    private func applyPendingInvite() {
        if let handle = store.consumeFriendInvite() {
            identifier = handle
            search()
        }
    }

    private func search() {
        guard canSearch else { return }
        Task {
            await store.searchUsers(query: identifier)
            didSearch = true
        }
    }

    private func sendRequest(to person: SnailProfile) {
        Task {
            if await store.requestFriend(identifier: person.username) {
                identifier = ""
                didSearch = false
                store.clearFriendSearch()
                requestSent = true
            }
        }
    }

    private func addressLabel(_ profile: SnailProfile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(profile.displayName.lowercased()).font(.body.weight(.medium))
            Text("\(profile.username.lowercased()) · \(profile.city.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
private struct ProfileEditorView: View {
    @EnvironmentObject private var store: ProductionStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var username: String
    @State private var city: String
    @State private var region: String
    @State private var isLocating = false

    init(profile: SnailProfile) {
        _displayName = State(initialValue: profile.displayName)
        _username = State(initialValue: profile.username.replacingOccurrences(of: "@", with: ""))
        let parts = profile.city.split(separator: ",", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _city = State(initialValue: parts.first ?? profile.city)
        _region = State(initialValue: parts.count > 1 ? parts[1] : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("your home snailbox") {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("what should people call you?", text: $displayName)
                        .textContentType(.nickname)
                    CityStateFields(city: $city, region: $region)
                    Button("use my current city", systemImage: "location") {
                        Task { await useCurrentCity() }
                    }
                    .disabled(isLocating)
                }
                Section {
                    Text("only your city and approximate coordinates are saved for delivery timing. your precise device location is not stored or shared.")
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
            .navigationTitle("edit snailbox")
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
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !region.isEmpty
    }

    private func save() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let resolvedCity = try await CityResolver.resolve("\(city), \(region)")
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

    private func useCurrentCity() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let resolved = try await CityResolver.currentCity()
            city = resolved.city
            region = resolved.region
        } catch {
            store.errorMessage = "we couldn’t use your location — allow location access or type your city"
        }
    }
}
