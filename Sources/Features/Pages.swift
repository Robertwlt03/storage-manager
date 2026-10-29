import SwiftUI

extension Pane {
    /// The view of each page.
    @ViewBuilder var page: some View {
        switch self {
        case .overview: OverviewView()
        case .explorer: ExplorerView()
        case .largeFiles: LargeFilesView()
        case .cleaner: CleanerView()
        case .apps: UnusedAppsView()
        case .temp: TempView()
        case .copies: CopiesView()
        case .volume(let path): VolumeView(path: path)
        }
    }
}
