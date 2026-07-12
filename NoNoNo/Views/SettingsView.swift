import SwiftUI

struct SettingsView: View {
    @Binding var gingerMode: Bool
    @Binding var hapticsOn: Bool
    @Binding var voiceOn: Bool
    @Binding var soundOn: Bool
    @AppStorage("cartoonMode") private var cartoonMode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("The Truth") {
                    Toggle(isOn: $gingerMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ginger Mode")
                            Text("Displays his hair color accurately.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("gingerToggle")
                }

                Section("Feel") {
                    Toggle("Haptic smacks", isOn: $hapticsOn)
                        .accessibilityIdentifier("hapticsToggle")
                    Toggle(isOn: $voiceOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("He yells out loud")
                            Text("“no, no no no no!” — plays even on silent.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("voiceToggle")
                    Toggle("Game sounds", isOn: $soundOn)
                        .accessibilityIdentifier("soundToggle")
                }

                Section("Face") {
                    Toggle(isOn: $cartoonMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cartoon Mode")
                            Text("Construction-paper Josh instead of the real one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("cartoonToggle")
                }

                Section("About") {
                    Text("Dedicated to the angriest, baldest, definitely-not-red-headed man in Hawaii.")
                    Text("He said “no no no,” but he was smiling, so we shipped it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
        }
    }
}
