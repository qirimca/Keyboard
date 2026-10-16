import SwiftUI

struct KeyboardSettingsView: View {
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    @AppStorage(KeyboardPreferences.cyrillicKey, store: KeyboardPreferences.defaults) private var cyrillicEnabled = true
    @AppStorage(KeyboardPreferences.suggestionsKey, store: KeyboardPreferences.defaults) private var suggestionsEnabled = true
    @Environment(\.dismiss) private var dismiss

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
                    Toggle(isOn: $suggestionsEnabled) { label("settings.suggestions") }
                } footer: {
                    label("settings.keyboardHelp")
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
