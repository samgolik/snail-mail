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
                    .accessibilityHint("retries the snailbox connection")
                }
                mailboxSection("traveling", letters: store.travelingLetters,
                               empty: "the road is quiet")
                    mailboxSection("ready to open", letters: store.arrivedLetters,
                               empty: "your snailbox is fresh")
                mailboxSection("on their way", letters: store.sentLetters,
                               empty: "no snails are traveling from you")
            }
            .padding()
        }
        .refreshable { await store.load() }
        .background(PastelBackground())
        .navigationTitle("snailbox")
        .foregroundStyle(Color.berryInk)
        .navigationDestination(for: SnailLetter.self) {
            ProductionLetterDetailView(letter: $0)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("hello, \(store.profile?.displayName.lowercased() ?? "friend")")
                .font(SnailType.title)
            Text("your tiny snailbox in \(store.profile?.city.lowercased() ?? "the world")")
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
                    .font(SnailType.headline)
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

struct ArchiveView: View {
    @EnvironmentObject private var store: ProductionStore
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.archivedLetters.isEmpty {
                    ContentUnavailableView(
                        "no trail yet",
                        systemImage: "sparkles",
                        description: Text("letters you open leave their little trail here")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(store.archivedLetters.enumerated()), id: \.element.id) { index, letter in
                            NavigationLink(value: letter) { archivedTile(letter, index: index) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(PastelBackground())
        .navigationTitle("snail trail")
        .navigationDestination(for: SnailLetter.self) {
            ProductionLetterDetailView(letter: $0)
        }
        .refreshable { await store.load() }
    }

    private func archivedTile(_ letter: SnailLetter, index: Int) -> some View {
        let person = store.person(id: letter.senderID)?.displayName.lowercased() ?? "a friend"
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                SlimeTrail(seed: index)
                    .stroke(
                        Color.snailGreen.opacity(0.28),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [2, 9])
                    )
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                    .padding(16)
                    .background(Color.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.powderBlue.opacity(0.28), radius: 8, y: 4)
            }
            .frame(height: 104)
            Text("from \(person)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text((letter.openedAt ?? letter.arrivesAt).formatted(date: .abbreviated, time: .omitted).lowercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.sand.opacity(0.8)) }
    }
}

private struct SlimeTrail: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let flip = seed.isMultiple(of: 2)
        path.move(to: CGPoint(x: flip ? rect.maxX : rect.minX, y: rect.maxY * 0.78))
        path.addCurve(
            to: CGPoint(x: flip ? rect.minX : rect.maxX, y: rect.minY * 1.8),
            control1: CGPoint(x: rect.midX * 1.35, y: rect.midY * 1.45),
            control2: CGPoint(x: rect.midX * 0.65, y: rect.midY * 0.35)
        )
        return path
    }
}
