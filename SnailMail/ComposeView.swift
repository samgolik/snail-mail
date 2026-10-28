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
            Section("To") {
                LabeledContent(store.otherProfile.name, value: store.otherProfile.city)
            }
            Section("Your letter") {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .accessibilityLabel("Letter message")
                Text("\(bodyText.count)/500")
                    .font(.caption)
                    .foregroundStyle(bodyText.count > 500 ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Section("Journey") {
                LabeledContent("Distance", value: "\(estimate.distanceMiles) miles")
                LabeledContent("Snail time", value: "\(estimate.snailDays) days")
#if DEBUG
                Text("Demo mode: one snail day takes 3 seconds.")
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
                Label("Send by snail", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.count > 500)
        }
        .navigationTitle("Write a Letter")
        .alert("Your snail is on its way!", isPresented: $showingSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Switch demo users to watch it arrive.")
        }
    }
}
