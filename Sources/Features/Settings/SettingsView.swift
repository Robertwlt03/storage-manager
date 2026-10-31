import SwiftUI

/// Only what macOS does not already cover: appearance and units come from System Settings. The
/// language can follow the Mac or be picked here.
struct SettingsView: View {
    @AppStorage(SettingsKey.scansAutomatically) private var scansAtLaunch = true
    @AppStorage(SettingsKey.showsMenuBarItem) private var showsMenuBarItem = true
    @AppStorage(SettingsKey.extraFolders) private var extraFolders = ""
    @AppStorage(SettingsKey.excludedFolders) private var excludedFolders = ""
    @State private var selectedExtraFolder: String?
    @State private var selectedExcludedFolder: String?
    @State private var language = AppLanguage.chosen

    var body: some View {
        Form {
            languagePicker
            Toggle(TextKey.autoScan.translated, isOn: $scansAtLaunch)
            Toggle(TextKey.showInMenuBar.translated, isOn: $showsMenuBarItem)
            LabeledContent(TextKey.extraFolders.translated) {
                folderEditor($extraFolders, selection: $selectedExtraFolder)
            }
            LabeledContent(TextKey.excludedFolders.translated) {
                folderEditor($excludedFolders, selection: $selectedExcludedFolder)
            }
            Text(TextKey.settingsSystemNote.translated).textRole(.hint)
        }
        .formStyle(.grouped)
        .frame(width: Layout.settingsWidth)
        // As tall as its rows, the restart row included, so no empty band stays below them.
        .fixedSize(horizontal: false, vertical: true)
        .appLocale()
    }

    @ViewBuilder private var languagePicker: some View {
        UI.MenuPicker(.appLanguage, selection: $language, inForm: true) {
            Text(TextKey.languageLikeMac.translated).tag(AppLanguage?.none)
            ForEach(AppLanguage.byNativeName, id: \.self) { choice in
                Text(choice.nativeName).tag(AppLanguage?.some(choice))
            }
        }
        .onChange(of: language) { AppLanguage.choose(language) }
        if language != Localizer.shared.chosenAtLaunch {
            HStack {
                Text(TextKey.languageRestartHint.translated).textRole(.hint)
                Spacer()
                languageRestartButton
            }
        }
    }

    private var languageRestartButton: some View {
        UI.ActionButton(TextKey.accessRestart.translated, .inline) { LifecycleService.relaunch() }
    }

    /// A list of folders stored one path per line, with buttons to add and remove.
    private func folderEditor(_ stored: Binding<String>, selection: Binding<String?>) -> some View {
        let folders = AppSettings.folders(from: stored.wrappedValue)
        return VStack(alignment: .leading, spacing: Space.small) {
            List(folders, id: \.self, selection: selection) { folder in
                Text(Paths.displayName(folder)).lineLimit(1).truncationMode(.middle)
            }
            .frame(height: Layout.folderListHeight)
            .overlay {
                if folders.isEmpty { Text(TextKey.none.translated).textRole(.hint) }
            }
            folderButtons(folders, stored: stored, selection: selection)
        }
    }

    private func folderButtons(
        _ folders: [String], stored: Binding<String>, selection: Binding<String?>
    ) -> some View {
        HStack(spacing: Space.extraSmall) {
            Button(TextKey.add.translated, systemImage: Symbols.add) {
                stored.wrappedValue = AppSettings.store(withChosenFolders(folders))
            }
            Button(TextKey.remove.translated, systemImage: Symbols.remove) {
                let remaining = folders.filter { folder in folder != selection.wrappedValue }
                stored.wrappedValue = AppSettings.store(remaining)
            }
            .disabled(selection.wrappedValue == nil)
        }
        .labelStyle(.iconOnly)
    }

    /// Adds the folders picked in the open panel; a folder already in the list stays once.
    private func withChosenFolders(_ folders: [String]) -> [String] {
        let allFolders = NSOrderedSet(array: folders + FinderService.chooseFolders())
        return allFolders.array.compactMap { folder in folder as? String }
    }
}
