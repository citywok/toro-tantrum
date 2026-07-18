import SwiftUI

struct SettingsView: View {
    @Binding var gingerMode: Bool
    @Binding var hapticsOn: Bool
    @Binding var voiceOn: Bool
    @Binding var soundOn: Bool
    @Binding var musicOn: Bool
    @AppStorage("cartoonMode") private var cartoonMode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("The Truth") {
                    Toggle(isOn: $gingerMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wasabi Mode")
                            Text("Displays his hatred of wasabi accurately.")
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
                    Toggle(isOn: $musicOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("8-bit Music")
                            Text("Old fashioned arcade chiptunes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("musicToggle")
                }

                Section("Face") {
                    Toggle(isOn: $cartoonMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cartoon Mode")
                            Text("Cartoon face instead of the real one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("cartoonToggle")
                }

                Section("About") {
                    Text("Dedicated to the man who once hid toro in his lap at dinner and we still talk about it years later.")
                    Text("He loves hot dogs and dino nuggets. He hates onions, cucumbers, tomatoes, and wasabi.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("He said nooooooo, but he was smiling, so we shipped it.")
                        .font(.caption.italic())
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
