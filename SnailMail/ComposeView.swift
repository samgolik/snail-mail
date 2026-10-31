import SwiftUI

struct ComposeView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var bodyText = ""
    @State private var recipientID = ""
    @State private var showingSent = false

    private var recipient: SnailProfile? {
        store.friends.first { $0.id == recipientID } ?? store.friends.first
    }

    var body: some View {
        Form {
            if store.friends.isEmpty {
                ContentUnavailableView(
                    "no address yet",
                    systemImage: "person.2.badge.plus",
                    description: Text("connect with a friend under you before writing your first letter")
                )
            } else {
                if !auth.isPhoneVerified {
                    Section {
                        Label("verify your phone under you before sending a letter", systemImage: "envelope.badge.shield.half.filled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("to") {
                    Picker("friend", selection: $recipientID) {
                        ForEach(store.friends) { friend in
                            Text("\(friend.displayName.lowercased()) · \(friend.city.lowercased())")
                                .tag(friend.id)
                        }
                    }
                }
                Section("your letter") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .background(Color.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("letter message")
                    Text("\(bodyText.count)/500")
                        .font(.caption)
                        .foregroundStyle(bodyText.count > 500 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(bodyText.count) of 500 characters")
                }
                if let recipient, let origin = store.profile {
                    Section("the little journey") {
                        LabeledContent("from", value: origin.city.lowercased())
                        LabeledContent("to", value: recipient.city.lowercased())
                        Text("the postmark and arrival time are set by the server when your letter leaves.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = store.errorMessage {
                    Section { Text(error).font(.caption).foregroundStyle(.red) }
                }
                Button {
                    guard let recipient else { return }
                    Task {
                        if await store.send(body: bodyText, to: recipient) {
                            bodyText = ""
                            showingSent = true
                        }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("send by snail", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 6)
                    }
                }
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          bodyText.count > 500 || store.isWorking || !auth.isPhoneVerified)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("write a letter")
        .onAppear {
            if recipientID.isEmpty { recipientID = store.friends.first?.id ?? "" }
        }
        .alert("your snail is on its way", isPresented: $showingSent) {
            Button("lovely", role: .cancel) {}
        } message: {
            Text("the letter is sealed. your friend can open it when it arrives.")
        }
    }
}
