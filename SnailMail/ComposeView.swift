import SwiftUI
import CoreLocation
import UIKit

struct ComposeView: View {
    private enum OriginState: Equatable {
        case checking, ready, permissionNeeded, denied, servicesDisabled, unavailable
    }

    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var bodyText = ""
    @State private var recipientID = ""
    @State private var showingSent = false
    @State private var currentOrigin: ResolvedCity?
    @State private var originState: OriginState = .checking

    private var recipient: SnailProfile? {
        store.friends.first { $0.id == recipientID } ?? store.friends.first
    }

    var body: some View {
        Form {
            if store.friends.isEmpty {
                ContentUnavailableView(
                    "no snailing address yet",
                    systemImage: "person.2.badge.plus",
                    description: Text("connect with a friend under you before writing your first letter")
                )
            } else {
                if !auth.isPhoneVerified {
                    Section {
                        Label("verify your phone under you before sending a letter", systemImage: "envelope.badge.shield.half.filled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("to") {
                    Picker("friend", selection: $recipientID) {
                        ForEach(store.friends) { friend in
                            Text(friend.displayName.lowercased())
                                .tag(friend.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                originSection
                Section("your letter") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .background(Color.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("letter message")
                    Text("\(bodyText.count)/500")
                        .font(.caption)
                        .foregroundStyle(bodyText.count > 500 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(bodyText.count) of 500 characters")
                }
                if let recipient {
                    Section("the little journey") {
                        journeyRow("from", currentOrigin?.name.lowercased() ?? "your current location")
                        journeyRow("to", recipient.city.lowercased())
                        Text("your snail starts from wherever you are when you send. only the city-level postmark is saved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = store.errorMessage {
                    Section { Text(error).font(.caption).foregroundStyle(.red) }
                }
                Button {
                    guard let recipient, let origin = currentOrigin else { return }
                    Task {
                        if await store.send(body: bodyText, to: recipient, from: origin) {
                            bodyText = ""
                            showingSent = true
                        }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("send by snail", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 6)
                    }
                }
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          bodyText.count > 500 || store.isWorking ||
                          originState != .ready || !auth.isPhoneVerified)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("write a letter")
        .onAppear {
            if recipientID.isEmpty { recipientID = store.friends.first?.id ?? "" }
        }
        .task { await prepareOrigin() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && [.denied, .servicesDisabled, .unavailable].contains(originState) {
                Task { await prepareOrigin() }
            }
        }
        .alert("your snail is on its way", isPresented: $showingSent) {
            Button("lovely", role: .cancel) {}
        } message: {
            Text("the letter is sealed. your friend can open it when it arrives.")
        }
    }

    @ViewBuilder
    private var originSection: some View {
        Section("starting point") {
            switch originState {
            case .checking:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("finding your current city…")
                }
                .foregroundStyle(.secondary)
            case .ready:
                Label(currentOrigin?.name.lowercased() ?? "current city ready", systemImage: "location.fill")
                    .foregroundStyle(Color.snailGreen)
            case .permissionNeeded:
                Label("location is needed before a letter can be sent", systemImage: "location.circle")
                Button("allow location") {
                    Task { await requestOriginPermission() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.snailGreen)
            case .denied:
                Label("location access is off, so sending is paused", systemImage: "location.slash")
                    .foregroundStyle(.red)
                Button("open location settings") { openSettings() }
            case .servicesDisabled:
                Label("location services are off on this iPhone", systemImage: "location.slash.fill")
                    .foregroundStyle(.red)
                Text("turn on Location Services in Settings before sending a letter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("open location settings") { openSettings() }
            case .unavailable:
                Label("we couldn’t find your current city", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                Button("try location again") {
                    Task { await requestOriginPermission() }
                }
            }
            Text("snail mail saves only the city-level postmark, never your precise location.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareOrigin() async {
        if originState == .ready, currentOrigin != nil { return }
        guard CLLocationManager.locationServicesEnabled() else {
            currentOrigin = nil
            originState = .servicesDisabled
            return
        }
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            await resolveOrigin()
        case .notDetermined:
            originState = .permissionNeeded
        case .denied, .restricted:
            currentOrigin = nil
            originState = .denied
        @unknown default:
            originState = .unavailable
        }
    }

    private func requestOriginPermission() async {
        await resolveOrigin()
    }

    private func resolveOrigin() async {
        originState = .checking
        do {
            currentOrigin = try await CityResolver.currentCity()
            originState = .ready
        } catch {
            currentOrigin = nil
            let status = CLLocationManager().authorizationStatus
            originState = (status == .denied || status == .restricted) ? .denied : .unavailable
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func journeyRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
