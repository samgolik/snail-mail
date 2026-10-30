import SwiftUI

struct MailboxView: View {
    @EnvironmentObject private var store: ProductionStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                greeting
                if let message = store.loadErrorMessage {
                    Button {
                        Task { await store.load() }
                    } label: {
                        Label("\(message). tap to try again", systemImage: "arrow.clockwise.circle")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.berryInk)
                    .accessibilityHint("retries the mailbox connection")
                }
                mailboxSection("traveling", letters: store.travelingLetters,
                               empty: "the road is quiet")
                mailboxSection("arrived", letters: store.arrivedLetters,
                               empty: "your mailbox is waiting")
                mailboxSection("sent", letters: store.sentLetters,
                               empty: "no letters have left your desk")
            }
            .padding()
        }
        .refreshable { await store.load() }
        .background(PastelBackground())
        .navigationTitle("snail mail")
        .foregroundStyle(Color.berryInk)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("hello, \(store.profile?.displayName.lowercased() ?? "friend")")
                .font(.title2.bold())
            Text("your tiny mailbox in \(store.profile?.city.lowercased() ?? "the world")")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func mailboxSection(_ title: String, letters: [SnailLetter], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            if letters.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: title == "traveling" ? "point.bottomleft.forward.to.point.topright.scurvepath" : "mail")
                        .font(.title2)
                    Text(empty)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .foregroundStyle(.secondary)
                .background(Color.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.powderBlue.opacity(0.65), lineWidth: 1)
                }
            } else {
                ForEach(letters) { letter in
                    NavigationLink(value: letter) { ProductionLetterRow(letter: letter) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: SnailLetter.self) {
            ProductionLetterDetailView(letter: $0)
        }
    }
}

private struct ProductionLetterRow: View {
    @EnvironmentObject private var store: ProductionStore
    let letter: SnailLetter

    var body: some View {
        let isReceived = letter.recipientID == store.profile?.id
        HStack(spacing: 14) {
            Image(systemName: letter.hasArrived(at: store.now) ? "envelope.open.fill" : "seal.fill")
                .font(.title)
                .foregroundStyle(Color.snailGreen)
            VStack(alignment: .leading, spacing: 6) {
                Text(isReceived
                     ? "from \(store.person(id: letter.senderID)?.displayName.lowercased() ?? "a friend")"
                     : "to \(store.person(id: letter.recipientID)?.displayName.lowercased() ?? "a friend")")
                    .font(.headline)
                if letter.hasArrived(at: store.now) {
                    Text(isReceived ? "ready to open" : "delivered").foregroundStyle(.secondary)
                } else {
                    ProgressView(value: letter.progress(at: store.now)).tint(.snailGreen)
                    Text("traveling from \(letter.originCity.lowercased())")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.card.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.sand.opacity(0.9)) }
        .shadow(color: Color.powderBlue.opacity(0.20), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("opens letter details")
    }

    private var accessibilityLabel: String {
        let isReceived = letter.recipientID == store.profile?.id
        let person = isReceived
            ? store.person(id: letter.senderID)?.displayName ?? "a friend"
            : store.person(id: letter.recipientID)?.displayName ?? "a friend"
        let direction = isReceived ? "from" : "to"
        if letter.hasArrived(at: store.now) {
            return "letter \(direction) \(person), \(isReceived ? "ready to open" : "delivered")"
        }
        let percent = Int(letter.progress(at: store.now) * 100)
        return "letter \(direction) \(person), traveling, \(percent) percent of the journey complete"
    }
}
