import SwiftUI
import UIKit

struct KeyboardSettingsView: View {
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    @AppStorage(KeyboardPreferences.cyrillicKey, store: KeyboardPreferences.defaults) private var cyrillicEnabled = true
    @AppStorage(KeyboardPreferences.suggestionsKey, store: KeyboardPreferences.defaults) private var suggestionsEnabled = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var cyrillicStatus = CyrillicStatus.unknown

    private enum CyrillicStatus { case enabled, missing, unknown }

    private func refreshKeyboardStatus() {
        let modes = UITextInputMode.activeInputModes
        let languages = modes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        if languages.contains(where: { $0.hasPrefix("crh-cyrl") }) {
            cyrillicStatus = .enabled
        } else if languages.contains("crh") || languages.isEmpty || modes.contains(where: { $0.primaryLanguage == nil }) {
            // Public UIKit APIs can omit script identifiers. Do not report a
            // keyboard as missing when the OS does not provide enough evidence.
            cyrillicStatus = .unknown
        } else {
            cyrillicStatus = .missing
        }
    }

    private func label(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $language) {
                        Text(verbatim: "Qırımtatarca").tag("crh")
                        Text(verbatim: "English").tag("en")
                        Text(verbatim: "Українська").tag("uk")
                    } label: { label("settings.language") }
                }
                Section {
                    Toggle(isOn: $cyrillicEnabled) { label("settings.cyrillic") }
                    if cyrillicEnabled {
                        if cyrillicStatus != .enabled {
                            Label {
                                label(cyrillicStatus == .missing ? "settings.missingCyrillic" : "settings.cyrillicUnverified")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                            }
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("settings.cyrillicWarning")
                        }
                        Label {
                            label("settings.enableBothKeyboards")
                        } icon: {
                            Image(systemName: "globe")
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("settings.enableBothKeyboards")
                    }
                    Toggle(isOn: $suggestionsEnabled) { label("settings.suggestions") }
                } footer: {
                    label("settings.keyboardHelp")
                }
            }
            .onAppear { refreshKeyboardStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshKeyboardStatus() }
            }
            .task {
                for await _ in NotificationCenter.default.notifications(named: UITextInputMode.currentInputModeDidChangeNotification) {
                    refreshKeyboardStatus()
                }
            }
            .navigationTitle(label("settings.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { label("settings.done") }
                }
            }
        }
    }
}
