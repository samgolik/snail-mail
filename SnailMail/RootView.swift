import SwiftUI
import CoreLocation
import UIKit

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if auth.isRestoringSession {
                LaunchView()
            } else if auth.isAuthenticated {
                AuthenticatedRoot()
            } else {
                AuthView()
            }
        }
        .fontDesign(.rounded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: auth.isAuthenticated)
    }
}

private struct AuthenticatedRoot: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.sessionUserID != auth.user?.uid {
                LaunchView()
            } else {
                switch store.loadState {
                case .idle, .loading:
                    LaunchView()
                case .failed:
                    ConnectionProblemView()
                case .loaded:
                    if store.profile == nil {
                        NewUserOnboardingView()
                    } else if !store.termsAccepted {
                        TermsAcceptanceView()
                    } else {
                        MainTabView()
                    }
                }
            }
        }
        .task(id: auth.user?.uid) {
            guard let userID = auth.user?.uid else { return }
            store.prepareSession(userID: userID)
            await store.load()
            if let token = UserDefaults.standard.string(forKey: "snailFCMToken") {
                await store.registerPushToken(token)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.hasLoaded else { return }
            Task { await store.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snailPushToken)) { note in
            guard let token = note.object as? String else { return }
            Task { await store.registerPushToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snailPushReceived)) { _ in
            Task { await store.load() }
        }
    }
}

private struct TermsAcceptanceView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var agreed = false

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Spacer(minLength: 48)
                    Image(systemName: "hand.raised.circle")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    Text("a kind little post office")
                        .font(SnailType.display)
                    Text("snail mail is for thoughtful correspondence. harassment, threats, hate, sexual exploitation, spam, impersonation, and illegal content are not allowed.")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Link("read the terms of use", destination: SnailLinks.page("terms"))
                        Link("read the community guidelines", destination: SnailLinks.page("community"))
                        Link("read the privacy policy", destination: SnailLinks.page("privacy"))
                    }
                    Toggle("i am at least 13 and agree to the terms and community guidelines", isOn: $agreed)
                        .tint(.snailGreen)
                    if let error = store.errorMessage {
                        MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
                    }
                    Button("enter the post office") {
                        Task { _ = await store.acceptTerms() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.snailGreen)
                    .frame(maxWidth: .infinity)
                    .disabled(!agreed || store.isWorking)
                    Button("sign out") {
                        store.resetSession()
                        Task { await auth.signOut() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(store.isWorking)
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
    }
}

private struct ConnectionProblemView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ZStack {
            PastelBackground()
            ContentUnavailableView {
                Label("the post office is out of reach", systemImage: "wifi.exclamationmark")
            } description: {
                VStack(spacing: 8) {
                    Text(store.loadErrorMessage ?? "we couldn’t collect your mail just now.")
                    if let diagnosticID = store.loadDiagnosticID {
                        Text("diagnostic \(diagnosticID) · \(store.loadDiagnosticStage ?? "unknown stage")")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } actions: {
                VStack(spacing: 12) {
                    Button("try again") {
                        Task { await store.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.snailGreen)
                    Button("sign out") {
                        store.resetSession()
                        Task { await auth.signOut() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .foregroundStyle(Color.berryInk)
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var store: ProductionStore

    var body: some View {
        TabView {
            NavigationStack { MailboxView().onAppear { store.clearError() } }
                .tabItem { Label("snailbox", systemImage: "mail.stack") }
            NavigationStack { ArchiveView().onAppear { store.clearError() } }
                .tabItem { Label("snail trail", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
            NavigationStack { ComposeView().onAppear { store.clearError() } }
                .tabItem { Label("write", systemImage: "square.and.pencil") }
            NavigationStack { AddressBookView().onAppear { store.clearError() } }
                .tabItem { Label("friends", systemImage: "person.2") }
            NavigationStack { SettingsView().onAppear { store.clearError() } }
                .tabItem { Label("you", systemImage: "person.crop.circle") }
        }
        .task { await SnailNotifications.requestPermission() }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            PastelBackground()
            VStack(spacing: 18) {
                PostalSeal()
                Text("snail mail")
                    .font(SnailType.display)
                ProgressView()
                    .tint(.snailGreen)
            }
            .foregroundStyle(Color.berryInk)
        }
    }
}

private struct NewUserOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var isMakingAddress = false

    private let pages = [
        OnboardingPage(
            icon: "heart.text.square.fill",
            eyebrow: "welcome to slow social",
            title: "some messages deserve a little journey",
            detail: "write something thoughtful, seal it up, and let a tiny snail carry it to a friend."
        ),
        OnboardingPage(
            icon: "seal.fill",
            eyebrow: "no peeking",
            title: "the letter stays sealed until it arrives",
            detail: "distance sets the pace. the waiting is part of the magic—and your friend gets a notification when the snail makes it."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            eyebrow: "friends, not followers",
            title: "exchange snailing addresses with people you know",
            detail: "find friends by handle, keep your phone number private, and report or block anyone whenever you need to."
        )
    ]

    var body: some View {
        if isMakingAddress {
            ProfileSetupView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            ZStack {
                PastelBackground()
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                            onboardingPage(item, index: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    Button(page == pages.count - 1 ? "make my snailing address" : "keep going") {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                            if page == pages.count - 1 {
                                isMakingAddress = true
                            } else {
                                page += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.snailGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)

                    Button(page == pages.count - 1 ? "back" : "skip the tour") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            if page == pages.count - 1 {
                                page -= 1
                            } else {
                                isMakingAddress = true
                            }
                        }
                    }
                    .font(SnailType.smallAction)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
            .foregroundStyle(Color.berryInk)
            .transition(.opacity)
        }
    }

    private func onboardingPage(_ item: OnboardingPage, index: Int) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 26)
            ZStack {
                OnboardingTrail(flip: index.isMultiple(of: 2))
                    .stroke(
                        Color.snailGreen.opacity(0.24),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [2, 12])
                    )
                    .frame(width: 240, height: 120)
                Circle()
                    .fill(Color.card.opacity(0.94))
                    .frame(width: 132, height: 132)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 52, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.snailGreen)
                    }
                    .overlay { Circle().stroke(Color.sand.opacity(0.9), lineWidth: 1) }
                    .shadow(color: Color.powderBlue.opacity(0.30), radius: 20, y: 10)
            }
            VStack(spacing: 12) {
                Text(item.eyebrow)
                    .font(SnailType.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(Color.clay)
                Text(item.title)
                    .font(SnailType.display)
                    .multilineTextAlignment(.center)
                Text(item.detail)
                    .font(SnailType.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 60)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingPage {
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
}

private struct OnboardingTrail: Shape {
    let flip: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: flip ? rect.maxX : rect.minX, y: rect.maxY * 0.76))
        path.addCurve(
            to: CGPoint(x: flip ? rect.minX : rect.maxX, y: rect.minY + 12),
            control1: CGPoint(x: rect.midX * 1.4, y: rect.maxY),
            control2: CGPoint(x: rect.midX * 0.6, y: rect.minY)
        )
        return path
    }
}

private struct PostalSeal: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.paper.opacity(0.92))
                .frame(width: 92, height: 92)
                .overlay {
                    Circle()
                        .stroke(Color.clay.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                        .padding(7)
                }
            Image(systemName: "envelope.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Color.snailGreen)
                .rotationEffect(.degrees(-4))
        }
        .shadow(color: Color.powderBlue.opacity(0.28), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

private struct ProfileSetupView: View {
    @EnvironmentObject private var store: ProductionStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var region = ""
    @State private var isLocating = false

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 52)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("set up your home snailbox")
                            .font(SnailType.display)
                        Text("choose the snailing address your friends will recognize on every little journey.")
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 14) {
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .authFieldStyle()
                        TextField("what should people call you?", text: $displayName)
                            .textContentType(.nickname)
                            .authFieldStyle()
                        CityStateFields(city: $city, region: $region)
                    }
                    Button("use my current city", systemImage: "location") {
                        Task { await useCurrentCity() }
                    }
                    .disabled(isLocating)
                    if let error = store.errorMessage {
                        MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
                    }
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if store.isWorking || isLocating {
                                ProgressView().tint(.white)
                            } else {
                                Text("set my home snailbox").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.snailGreen)
                    .disabled(displayName.isEmpty || username.isEmpty || city.isEmpty || region.isEmpty ||
                              store.isWorking || isLocating)
                    Text("this city is where friends send your snails. your live location is used only when you send one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
    }

    private func save() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let resolvedCity = try await CityResolver.resolve("\(city), \(region)")
            _ = await store.saveProfile(
                displayName: displayName,
                username: username,
                city: resolvedCity.name,
                latitude: resolvedCity.latitude,
                longitude: resolvedCity.longitude
            )
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

private struct ProfileLocationError: Error {}

struct ResolvedCity {
    let name: String
    let city: String
    let region: String
    let latitude: Double
    let longitude: Double
}

enum CityResolver {
    @MainActor private static var cachedCurrentCity: (city: ResolvedCity, savedAt: Date)?

    static func resolve(_ query: String) async throws -> ResolvedCity {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileLocationError() }

        let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
        guard let placemark = placemarks.first,
              let coordinate = placemark.location?.coordinate,
              let locality = placemark.locality ?? placemark.subAdministrativeArea else {
            throw ProfileLocationError()
        }

        let region = placemark.administrativeArea ?? placemark.country
        let canonicalName = [locality, region]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !canonicalName.isEmpty else { throw ProfileLocationError() }
        return ResolvedCity(
            name: canonicalName,
            city: locality,
            region: region ?? "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    @MainActor
    static func currentCity() async throws -> ResolvedCity {
        if let cachedCurrentCity,
           Date().timeIntervalSince(cachedCurrentCity.savedAt) < 600 {
            return cachedCurrentCity.city
        }
        let request = CurrentLocationRequest()
        let location = try await request.start()
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first,
              let locality = placemark.locality ?? placemark.subAdministrativeArea else {
            throw ProfileLocationError()
        }
        let region = placemark.administrativeArea ?? placemark.country
        let name = [locality, region]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !name.isEmpty else { throw ProfileLocationError() }
        let result = ResolvedCity(
            name: name,
            city: locality,
            region: region ?? "",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        cachedCurrentCity = (result, .now)
        return result
    }
}

struct CityStateFields: View {
    @Binding var city: String
    @Binding var region: String

    var body: some View {
        TextField("city", text: $city)
            .textContentType(.addressCity)
            .authFieldStyle()
        Picker("state", selection: $region) {
            Text("choose a state").tag("")
            ForEach(USRegions.all, id: \.abbreviation) { item in
                Text(item.name.lowercased()).tag(item.abbreviation)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(Color.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum USRegions {
    static let all: [(name: String, abbreviation: String)] = [
        ("Alabama", "AL"), ("Alaska", "AK"), ("Arizona", "AZ"), ("Arkansas", "AR"),
        ("California", "CA"), ("Colorado", "CO"), ("Connecticut", "CT"), ("Delaware", "DE"),
        ("District of Columbia", "DC"), ("Florida", "FL"), ("Georgia", "GA"), ("Hawaii", "HI"),
        ("Idaho", "ID"), ("Illinois", "IL"), ("Indiana", "IN"), ("Iowa", "IA"),
        ("Kansas", "KS"), ("Kentucky", "KY"), ("Louisiana", "LA"), ("Maine", "ME"),
        ("Maryland", "MD"), ("Massachusetts", "MA"), ("Michigan", "MI"), ("Minnesota", "MN"),
        ("Mississippi", "MS"), ("Missouri", "MO"), ("Montana", "MT"), ("Nebraska", "NE"),
        ("Nevada", "NV"), ("New Hampshire", "NH"), ("New Jersey", "NJ"), ("New Mexico", "NM"),
        ("New York", "NY"), ("North Carolina", "NC"), ("North Dakota", "ND"), ("Ohio", "OH"),
        ("Oklahoma", "OK"), ("Oregon", "OR"), ("Pennsylvania", "PA"), ("Rhode Island", "RI"),
        ("South Carolina", "SC"), ("South Dakota", "SD"), ("Tennessee", "TN"), ("Texas", "TX"),
        ("Utah", "UT"), ("Vermont", "VT"), ("Virginia", "VA"), ("Washington", "WA"),
        ("West Virginia", "WV"), ("Wisconsin", "WI"), ("Wyoming", "WY")
    ]
}

private final class CurrentLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if let cached = manager.location,
               cached.horizontalAccuracy >= 0,
               Date().timeIntervalSince(cached.timestamp) < 300 {
                finish(.success(cached))
                return
            }
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                self?.finish(.failure(ProfileLocationError()))
            }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            default:
                finish(.failure(ProfileLocationError()))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(ProfileLocationError()))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(.failure(ProfileLocationError()))
            return
        }
        finish(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }
}

private struct AuthView: View {
    private enum Field { case phone, code }

    @EnvironmentObject private var auth: AuthManager
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
    @State private var agreedToCreateAccount = false
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 48)
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    VStack(spacing: 8) {
                        Text("snail mail")
                            .font(SnailType.display)
                        Text("messages worth waiting for")
                            .foregroundStyle(.secondary)
                    }
                    authCard
                    Text("your letters move slowly. your account should not.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
    }

    private var authCard: some View {
        VStack(spacing: 18) {
            Text("your phone number is your snail mail account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("mobile number", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .phone)
                .authFieldStyle()

            if codeSent {
                TextField("6-digit code", text: $verificationCode)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .code)
                    .authFieldStyle()
            } else {
                Text("we’ll text a one-time code. new numbers create an account; returning numbers sign in. standard rates may apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("i am at least 13 and agree to the terms and community guidelines", isOn: $agreedToCreateAccount)
                    .font(.caption)
                    .tint(.snailGreen)
                HStack(spacing: 14) {
                    Link("terms", destination: SnailLinks.page("terms"))
                    Link("community", destination: SnailLinks.page("community"))
                    Link("privacy", destination: SnailLinks.page("privacy"))
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = auth.errorMessage {
                MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
            }
            if let notice = auth.noticeMessage {
                MessageRow(text: notice, systemImage: "checkmark.circle", color: .snailGreen)
            }

            Button {
                Task {
                    if codeSent {
                        _ = await auth.signInWithPhone(code: verificationCode)
                    } else {
                        codeSent = await auth.requestPhoneVerification(phoneNumber)
                        if codeSent { focusedField = .code }
                    }
                }
            } label: {
                Group {
                    if auth.isWorking {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text(codeSent ? "checking your code…" : "getting your code ready…")
                                .font(SnailType.smallAction)
                        }
                    } else {
                        Text(codeSent ? "enter the post office" : "text me a code")
                            .font(SnailType.button)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(.snailGreen)
            .controlSize(.large)
            .disabled(phoneNumber.isEmpty || auth.isWorking ||
                      (!codeSent && !agreedToCreateAccount) ||
                      (codeSent && verificationCode.count < 6))

            if codeSent {
                Button("use a different number") {
                    verificationCode = ""
                    codeSent = false
                    focusedField = .phone
                    auth.clearMessages()
                }
                .font(.subheadline)
                .disabled(auth.isWorking)
            }
        }
        .padding(22)
        .background(Color.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardBorder.opacity(0.9), lineWidth: 1)
        }
    }
}

private struct MessageRow: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func authFieldStyle() -> some View {
        padding(14)
            .background(Color.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension Color {
    static let snailGreen = adaptive(
        light: UIColor(red: 0.32, green: 0.48, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.75, blue: 0.64, alpha: 1)
    )
    static let paper = adaptive(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.15, blue: 0.13, alpha: 1)
    )
    static let sage = adaptive(
        light: UIColor(red: 0.72, green: 0.80, blue: 0.70, alpha: 1),
        dark: UIColor(red: 0.27, green: 0.36, blue: 0.30, alpha: 1)
    )
    static let powderBlue = adaptive(
        light: UIColor(red: 0.73, green: 0.82, blue: 0.87, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.38, blue: 0.43, alpha: 1)
    )
    static let clay = adaptive(
        light: UIColor(red: 0.68, green: 0.48, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.84, green: 0.66, blue: 0.53, alpha: 1)
    )
    static let sand = adaptive(
        light: UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1),
        dark: UIColor(red: 0.44, green: 0.38, blue: 0.29, alpha: 1)
    )
    static let berryInk = adaptive(
        light: UIColor(red: 0.24, green: 0.27, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.90, blue: 0.84, alpha: 1)
    )
    static let card = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.19, blue: 0.17, alpha: 1)
    )
    static let cardBorder = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.55, blue: 0.48, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct PastelBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.paper, .powderBlue.opacity(0.24), .sage.opacity(0.30)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

enum SnailType {
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let smallAction = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let eyebrow = Font.system(size: 13, weight: .bold, design: .rounded)
}
