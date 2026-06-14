import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section(settings.text(.general)) {
                Picker(settings.text(.language), selection: $settings.language) {
                    Text(settings.text(.followSystem)).tag(AppLanguage.system)
                    Text(settings.text(.english)).tag(AppLanguage.english)
                    Text(settings.text(.chineseSimplified)).tag(AppLanguage.zhHans)
                }
                .pickerStyle(.menu)

                Picker(settings.text(.defaultOpenMode), selection: $settings.defaultMode) {
                    Text(settings.text(.write)).tag(EditorMode.write)
                    Text(settings.text(.sideBySide)).tag(EditorMode.split)
                    Text(settings.text(.read)).tag(EditorMode.read)
                }
                .pickerStyle(.segmented)

                Picker(settings.text(.newDocumentMode), selection: $settings.newDocumentMode) {
                    Text(settings.text(.write)).tag(EditorMode.write)
                    Text(settings.text(.sideBySide)).tag(EditorMode.split)
                    Text(settings.text(.read)).tag(EditorMode.read)
                }
                .pickerStyle(.segmented)

                Toggle(settings.text(.showOutlineByDefault), isOn: $settings.showsOutlineByDefault)
            }
        }
        .formStyle(.grouped)
        .padding(22)
        .frame(width: 480)
        .navigationTitle(settings.text(.settingsTitle))
    }
}
