import SwiftUI

struct ProductionLetterDetailView: View {
    @EnvironmentObject private var store: ProductionStore
    @Environment(\.dismiss) private var dismiss
    let letter: SnailLetter
    @State private var showingReport = false
    @State private var showingBlock = false
    @State private var reportReason = ""
    @State private var reportSent = false
    @State private var isLoadingOpenedLetter = false

    var body: some View {
        ScrollView {
        VStack(spacing: 24) {
            if letter.senderID == store.profile?.id {
                Image(systemName: letter.hasArrived(at: store.now) ? "checkmark.seal.fill" : "seal.fill")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                Text(letter.hasArrived(at: store.now) ? "delivered" : "still on the way")
                    .font(SnailType.title)
                Text("your letter is \(letter.hasArrived(at: store.now) ? "waiting in" : "traveling toward") \(letter.destinationCity.lowercased()). the seal belongs to its recipient.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else if letter.hasArrived(at: store.now) {
                Image(systemName: store.openedBodies[letter.id] == nil ? "envelope.fill" : "envelope.open.fill")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                if isLoadingOpenedLetter && store.openedBodies[letter.id] == nil {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("unfolding your letter…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else if let body = store.openedBodies[letter.id] {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(body)
                            .font(SnailType.body)
                            .lineSpacing(5)
                        Divider()
                        Text("from \(store.person(id: letter.senderID)?.displayName.lowercased() ?? "a friend") in \(letter.originCity.lowercased())")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.paper, in: RoundedRectangle(cornerRadius: 26))
                    .overlay { RoundedRectangle(cornerRadius: 26).stroke(Color.sand.opacity(0.9)) }
                    .shadow(color: Color.powderBlue.opacity(0.22), radius: 14, y: 6)
                } else {
                    Text("it made it").font(SnailType.title)
                    Text("the seal can finally be broken.")
                        .foregroundStyle(.secondary)
                    Button {
                        isLoadingOpenedLetter = true
                        Task {
                            await store.open(letter)
                            isLoadingOpenedLetter = false
                        }
                    } label: {
                        HStack(spacing: 9) {
                            if isLoadingOpenedLetter {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "envelope.open")
                            }
                            Text(isLoadingOpenedLetter ? "breaking the seal…" : "open letter")
                        }
                        .frame(minWidth: 176)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.snailGreen)
                    .disabled(isLoadingOpenedLetter)
                }
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 70, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                Text("still on the way").font(SnailType.title)
                Text("this letter is traveling from \(letter.originCity.lowercased()) to \(letter.destinationCity.lowercased()). its contents stay sealed until it arrives.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if !letter.hasArrived(at: store.now) {
                JourneyRouteView(letter: letter, now: store.now)
                    .frame(height: 62)
                    .padding(.horizontal, 8)
                Text("\(letter.distanceMiles) miles · about \(letter.travelTimeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        }
        .background(PastelBackground().ignoresSafeArea())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("letter")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: isLoadingOpenedLetter)
        .animation(.easeInOut(duration: 0.2), value: store.openedBodies[letter.id] != nil)
        .task(id: letter.id) {
            if isReceived && letter.openedAt != nil && store.openedBodies[letter.id] == nil {
                isLoadingOpenedLetter = true
                await store.open(letter)
                isLoadingOpenedLetter = false
            }
        }
        .toolbar {
            if isReceived, sender != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("report this letter", systemImage: "exclamationmark.bubble") {
                            showingReport = true
                        }
                        Button("block sender", systemImage: "hand.raised", role: .destructive) {
                            showingBlock = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("letter safety options")
                    }
                }
            }
        }
        .alert("report this letter", isPresented: $showingReport) {
            TextField("what happened?", text: $reportReason)
            Button("cancel", role: .cancel) { reportReason = "" }
            Button("send report") {
                guard let sender else { return }
                let reason = reportReason
                reportReason = ""
                Task {
                    if await store.report(sender, reason: reason, letterID: letter.id) {
                        reportSent = true
                    }
                }
            }
            .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("reports are private and reviewed for safety.")
        }
        .confirmationDialog("block this sender?", isPresented: $showingBlock) {
            Button("block", role: .destructive) {
                guard let sender else { return }
                Task {
                    if await store.block(sender) { dismiss() }
                }
            }
        } message: {
            Text("you will no longer be connected or able to exchange letters.")
        }
        .alert("report sent", isPresented: $reportSent) {
            Button("done", role: .cancel) {}
        } message: {
            Text("thank you. the report is private and ready for review.")
        }
    }

    private var isReceived: Bool { letter.recipientID == store.profile?.id }
    private var sender: SnailProfile? { store.person(id: letter.senderID) }
}

private struct JourneyRouteView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let letter: SnailLetter
    let now: Date

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 18
            let width = max(proxy.size.width - inset * 2, 1)
            let progress = letter.progress(at: now)
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: inset, y: 25))
                    path.addLine(to: CGPoint(x: inset + width, y: 25))
                }
                .stroke(Color.clay.opacity(0.48), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))

                routePin
                    .position(x: inset, y: 25)
                routePin
                    .position(x: inset + width, y: 25)

                TinySnail()
                    .position(x: inset + width * progress, y: 22)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: progress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(letter.progress(at: now) * 100)) percent of the journey complete")
    }

    private var routePin: some View {
        Circle()
            .fill(Color.paper)
            .frame(width: 13, height: 13)
            .overlay { Circle().stroke(Color.clay, lineWidth: 2) }
    }
}

private struct TinySnail: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule()
                .fill(Color.snailGreen)
                .frame(width: 34, height: 9)
                .offset(y: 4)
            Circle()
                .fill(Color.sand)
                .frame(width: 25, height: 25)
                .overlay {
                    Circle()
                        .stroke(Color.clay.opacity(0.75), lineWidth: 2)
                        .padding(5)
                }
                .offset(x: 5, y: -1)
            Circle()
                .fill(Color.snailGreen)
                .frame(width: 9, height: 9)
                .offset(x: 28, y: 1)
        }
        .frame(width: 38, height: 31)
        .shadow(color: Color.powderBlue.opacity(0.24), radius: 4, y: 2)
    }
}

// Retained for local unit tests of the accelerated delivery engine.
struct LetterDetailView: View {
    let letter: Letter
    var body: some View { EmptyView() }
}
