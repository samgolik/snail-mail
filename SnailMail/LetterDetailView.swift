import SwiftUI

struct LetterDetailView: View {
    @EnvironmentObject private var store: MailStore
    let letter: Letter

    var body: some View {
        VStack(spacing: 24) {
            if letter.hasArrived(at: store.now) {
                Text("💌").font(.system(size: 64))
                VStack(alignment: .leading, spacing: 18) {
                    Text(letter.body)
                        .font(.title3)
                    Divider()
                    Text("from \(store.profile(id: letter.senderID).name.lowercased()) in \(letter.originCity.lowercased())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 26))
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.peach.opacity(0.8), lineWidth: 1)
                }
                .shadow(color: Color.lavender.opacity(0.25), radius: 14, y: 6)
            } else {
                Text("🐌").font(.system(size: 72))
                Text("still on the way...")
                    .font(.title.bold())
                ProgressView(value: letter.progress(at: store.now))
                    .tint(.snailGreen)
                Text("this little letter is traveling from \(letter.originCity.lowercased()) to \(letter.destinationCity.lowercased()). its contents stay sealed until it arrives ♡")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
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
