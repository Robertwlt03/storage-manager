import SwiftUI

/// Code-signature copies of all apps found in folder X.
struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = model.copyGroups
        UI.Page(.copies) {
            if !model.hasData || (model.scanning && groups.isEmpty) {  // the temporary area is measured last
                UI.Placeholder(.notMeasured, in: .page)
            } else if groups.isEmpty {
                UI.Placeholder(
                    .empty(
                        title: TextKey.noCopies.translated, symbol: Symbols.copies,
                        detail: TextKey.noCopiesDetail.translated), in: .page)
            }
            ForEach(groups) { CopyGroupCard(group: $0) }
        }
    }
}
