import SwiftUI

struct MailboxView: View {
    @EnvironmentObject private var store: MailStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                greeting
                section("Traveling", letters: store.travelingLetters, empty: "No snails on the road")
                section("Arrived", letters: store.arrivedLetters, empty: "No letters yet")
            }
            .padding()
        }
        .background(Color.paper.opacity(0.45))
        .navigationTitle("Snail Mail")
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Hello, \(store.activeProfile.name)")
                .font(.title2.bold())
            Text("Your mailbox in \(store.activeProfile.city)")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, letters: [Letter], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if letters.isEmpty {
                Text(empty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
                    .foregroundStyle(.secondary)
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(letters) { letter in
                    NavigationLink(value: letter) { LetterRow(letter: letter) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: Letter.self) { LetterDetailView(letter: $0) }
    }
}

private struct LetterRow: View {
    @EnvironmentObject private var store: MailStore
    let letter: Letter

    var body: some View {
        HStack(spacing: 14) {
            Text(letter.hasArrived(at: store.now) ? "💌" : "🐌")
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 5) {
                Text("From \(store.profile(id: letter.senderID).name)")
                    .font(.headline)
                if letter.hasArrived(at: store.now) {
                    Text("Ready to open")
                } else {
                    ProgressView(value: letter.progress(at: store.now))
                    Text("Traveling from \(letter.originCity)")
                        .font(.caption)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
