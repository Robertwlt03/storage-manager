import SwiftUI

/// Code-signature copies of all apps found in folder X.
struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let copyGroups = model.copyGroups
        UI.Page(.copies) {
            // The temporary area is measured last.
            if !model.hasData || (model.scanning && copyGroups.isEmpty) {
                UI.Placeholder(.notMeasured, in: .page)
            } else if copyGroups.isEmpty {
                UI.Placeholder(
                    .empty(
                        title: TextKey.noCopies.translated, symbol: Symbols.copies,
                        detail: TextKey.noCopiesDetail.translated), in: .page)
            }
            ForEach(copyGroups) { group in CopyGroupCard(group: group) }
        }
    }
}
