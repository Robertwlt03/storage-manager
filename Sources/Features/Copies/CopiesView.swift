import SwiftUI

/// Code-signature copies of all apps found in folder X.
struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let copyGroups = model.copyGroups
        UI.Page(.copies) {
            // The temporary area is measured last, so copies show up only at the end of a scan.
            if !model.hasData || (model.isScanning && copyGroups.isEmpty) {
                UI.Placeholder(.notMeasured, in: .page)
            } else if copyGroups.isEmpty {
                UI.Placeholder(
                    .empty(
                        title: TextKey.noCopies.translated, symbol: Symbols.success,
                        detail: TextKey.noCopiesDetail.translated), in: .page)
            }
            ForEach(copyGroups) { group in CopyGroupCard(group: group) }
        }
    }
}
