import SwiftUI

/// Code-signature copies of all apps found in folder X.
struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = model.copyGroups
        UI.page(.copies) {
            if !model.hasData || (model.scanning && groups.isEmpty) {  // the temporary area is measured last
                UI.notMeasured()
            } else if groups.isEmpty {
                UI.empty(Loc.noCopies.s, symbol: Symbols.copies, detail: Loc.noCopiesDetail.s)
            }
            ForEach(groups) { CopyGroupCard(group: $0) }
        }
    }
}
