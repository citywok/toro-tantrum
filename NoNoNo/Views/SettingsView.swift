import SwiftUI

struct SettingsView: View {
    @Binding var gingerMode: Bool
    @Binding var hapticsOn: Bool
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
