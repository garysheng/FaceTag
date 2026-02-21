import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenClaw Gateway") {
                    TextField("URL", text: $settings.gatewayURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Gateway Password", text: $settings.gatewayPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Hooks Token", text: $settings.hooksToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Telegram") {
                    TextField("Chat ID", text: $settings.telegramChatID)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                }

                Section {
                    if settings.isConfigured {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Fill in all fields above", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
