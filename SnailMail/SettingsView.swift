import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MailStore
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("viewing as") {
                Picker("demo user", selection: $store.activeProfile) {
                    ForEach(store.profiles) { profile in
                        Text("\(profile.name.lowercased()) · \(profile.city.lowercased())").tag(profile)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("how to test") {
                Text("write a letter as sam, switch to justin, then watch the traveling snail. the dc-to-columbus demo arrives in about one minute")
            }
            Section {
                Button("reset demo", role: .destructive) { confirmReset = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PastelBackground())
        .foregroundStyle(Color.berryInk)
        .navigationTitle("demo controls")
        .confirmationDialog("delete all demo letters?", isPresented: $confirmReset) {
            Button("reset", role: .destructive) { store.resetDemo() }
        }
    }
}
