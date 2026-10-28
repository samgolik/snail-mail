import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Viewing as") {
                Picker("Demo user", selection: $store.activeProfile) {
                    ForEach(store.profiles) { profile in
                        Text("\(profile.name) · \(profile.city)").tag(profile)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("How to test") {
                Text("Write a letter as Sam, switch to Justin, then watch the traveling snail. The DC-to-Columbus demo arrives in about one minute.")
            }
            Section {
                Button("Reset demo", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Demo Controls")
        .confirmationDialog("Delete all demo letters?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { store.resetDemo() }
        }
    }
}
