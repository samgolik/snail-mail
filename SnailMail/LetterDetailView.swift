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
                    Text("From \(store.profile(id: letter.senderID).name) in \(letter.originCity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 20))
            } else {
                Text("🐌").font(.system(size: 72))
                Text("Still on the way")
                    .font(.title.bold())
                ProgressView(value: letter.progress(at: store.now))
                Text("This letter is traveling from \(letter.originCity) to \(letter.destinationCity). Its contents stay sealed until it arrives.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Letter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
