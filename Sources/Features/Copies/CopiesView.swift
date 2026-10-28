import SwiftUI

/// Code-signature copies of all apps found in folder X.
struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = model.copyGroups
        UI.page(Loc.paneCopies.s) {
            UI.note(Loc.copiesIntro.s)
            if !model.hasData {
                UI.notMeasured().frame(minHeight: Layout.placeholderHeight)
            } else if groups.isEmpty {
                UI.empty(Loc.noCopies.s, symbol: Symbols.copies, detail: Loc.noCopiesDetail.s).frame(minHeight: Layout.placeholderHeight)
            }
            ForEach(groups) { CopyGroupCard(group: $0) }
        }
    }
}
