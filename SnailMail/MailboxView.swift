import SwiftUI

struct MailboxView: View {
    @EnvironmentObject private var store: MailStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                greeting
                section("traveling", letters: store.travelingLetters, empty: "no snails on the road yet")
                section("arrived", letters: store.arrivedLetters, empty: "no letters yet")
            }
            .padding()
        }
        .background(PastelBackground())
        .navigationTitle("snail mail")
        .foregroundStyle(Color.berryInk)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("hello, \(store.activeProfile.name.lowercased())")
                .font(.title2.bold())
            Text("your tiny mailbox in \(store.activeProfile.city.lowercased())")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, letters: [Letter], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            if letters.isEmpty {
                Text(empty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
                    .foregroundStyle(.secondary)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.powderBlue.opacity(0.65), lineWidth: 1)
                    }
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
                Text("from \(store.profile(id: letter.senderID).name.lowercased())")
                    .font(.headline)
                if letter.hasArrived(at: store.now) {
                    Text("ready to open")
                } else {
                    ProgressView(value: letter.progress(at: store.now))
                        .tint(.snailGreen)
                    Text("traveling from \(letter.originCity.lowercased())")
                        .font(.caption)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.sand.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color.powderBlue.opacity(0.20), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}
