import SwiftUI

struct ComposeView: View {
    @EnvironmentObject private var store: MailStore
    @State private var bodyText = ""
    @State private var showingSent = false

    private var estimate: DeliveryEstimate {
        DeliveryCalculator.estimate(from: store.activeProfile, to: store.otherProfile)
    }

    var body: some View {
        Form {
            Section("to") {
                LabeledContent(
                    store.otherProfile.name.lowercased(),
                    value: store.otherProfile.city.lowercased()
                )
            }
            Section("your letter") {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .background(Color.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("letter message")
                Text("\(bodyText.count)/500")
                    .font(.caption)
                    .foregroundStyle(bodyText.count > 500 ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Section("the little journey") {
                LabeledContent("distance", value: "\(estimate.distanceMiles) miles")
                LabeledContent("snail time", value: "\(estimate.snailDays) days")
#if DEBUG
                Text("demo magic: one snail day takes 3 seconds ✨")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#endif
            }
            Button {
                if store.send(body: bodyText, to: store.otherProfile) != nil {
                    bodyText = ""
                    showingSent = true
                }
            } label: {
                Label("send by snail  🐌", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding(.vertical, 6)
            }
            .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.count > 500)
        }
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("write a letter")
        .alert("your snail is on its way!", isPresented: $showingSent) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("switch demo users to watch it arrive ♡")
        }
    }
}
