import SwiftUI

struct AppearanceSettings: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system
    @AppStorage(SettingsKey.palette) private var palette = ChartPalette.colourful
    @AppStorage(SettingsKey.binaryUnits) private var binaryUnits = false

    var body: some View {
        Form {
            Picker(Loc.appearance.s, selection: $appearance) {
                ForEach(AppAppearance.allCases) { Text($0.title.s).tag($0) }
            }
            Picker(Loc.chartColors.s, selection: $palette) {
                ForEach(ChartPalette.allCases) { Text($0.title.s).tag($0) }
            }
            DetailToggle(title: .binaryUnits, detail: Loc.binaryUnitsDetail.s, isOn: $binaryUnits)
        }
        .frame(height: Layout.settingsAppearanceHeight)
    }
}

struct ScanSettings: View {
    @AppStorage(SettingsKey.autoScan) private var autoScan = true
    @AppStorage(SettingsKey.pauseOnLowPower) private var pauseOnLowPower = true
    @AppStorage(SettingsKey.eco) private var eco = true
    @AppStorage(SettingsKey.extraFolders) private var extraFolders = ""
    @State private var selected: String?

    var body: some View {
        let folders = AppSettings.folders(from: extraFolders)
        Form {
            Toggle(Loc.autoScan.s, isOn: $autoScan)
            DetailToggle(title: .pauseLowPower, detail: Loc.pauseLowPowerDetail.s, isOn: $pauseOnLowPower)
            DetailToggle(title: .eco, detail: Loc.ecoDetail.s, isOn: $eco)
            LabeledContent(Loc.extraFolders.s) {
                VStack(alignment: .leading, spacing: 6) {
                    List(folders, id: \.self, selection: $selected) { Text(Paths.display($0)).lineLimit(1).truncationMode(.middle) }
                        .frame(height: Layout.folderListHeight)
                        .overlay { if folders.isEmpty { Text(Loc.none.s).foregroundStyle(.muted) } }
                    HStack(spacing: 4) {
                        Button(Loc.add.s, systemImage: Symbols.add) {
                            extraFolders = AppSettings.store(Array(NSOrderedSet(array: folders + FinderService.chooseFolders()))
                                .compactMap { $0 as? String })
                        }
                        Button(Loc.remove.s, systemImage: Symbols.remove) {
                            extraFolders = AppSettings.store(folders.filter { $0 != selected })
                        }
                        .disabled(selected == nil)
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .frame(height: Layout.settingsScanHeight)
    }
}
