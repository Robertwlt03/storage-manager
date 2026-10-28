import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label(Loc.tabGeneral.s, systemImage: Symbols.tabGeneral) }
            AppearanceSettings().tabItem { Label(Loc.tabAppearance.s, systemImage: Symbols.tabAppearance) }
            ScanSettings().tabItem { Label(Loc.tabScanning.s, systemImage: Symbols.tabScanning) }
        }
        .formStyle(.grouped)
        .frame(width: Layout.settingsWidth)
        .syncPreferences()
    }
}

/// A toggle with a muted explanation below.
struct DetailToggle: View {
    let title: Loc
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title.s)
            Text(detail).foregroundStyle(.muted)
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.language) private var language = AppLanguage.system

    var body: some View {
        Form {
            Picker(Loc.language.s, selection: $language) {
                ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
            }
            Text(Loc.languageNote.s).foregroundStyle(.muted)
            LabeledContent(Loc.fullDiskAccess.s) {
                if model.hasFullDiskAccess { UI.status(Loc.accessGranted.s, symbol: Symbols.success, .good) } else {
                    UI.button(Loc.accessOpenSettings.s) { FinderService.openFullDiskAccessSettings() }
                }
            }
        }
        .frame(height: Layout.settingsGeneralHeight)
        .onAppear { model.refreshAccess() }
    }
}
