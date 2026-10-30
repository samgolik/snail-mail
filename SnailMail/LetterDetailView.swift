import SwiftUI

struct ProductionLetterDetailView: View {
    @EnvironmentObject private var store: ProductionStore
    let letter: SnailLetter

    var body: some View {
        VStack(spacing: 24) {
            if letter.hasArrived(at: store.now) {
                Image(systemName: store.openedBodies[letter.id] == nil ? "envelope.fill" : "envelope.open.fill")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                if let body = store.openedBodies[letter.id] {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(body).font(.title3)
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
                    Text("it made it").font(.title.bold())
                    Text("the seal can finally be broken.")
                        .foregroundStyle(.secondary)
                    Button("open letter") {
                        Task { await store.open(letter) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.snailGreen)
                    .disabled(store.isWorking)
                }
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 70, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                Text("still on the way").font(.title.bold())
                ProgressView(value: letter.progress(at: store.now)).tint(.snailGreen)
                Text("this letter is traveling from \(letter.originCity.lowercased()) to \(letter.destinationCity.lowercased()). its contents stay sealed until it arrives.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("letter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Retained for local unit tests of the accelerated delivery engine.
struct LetterDetailView: View {
    let letter: Letter
    var body: some View { EmptyView() }
}
