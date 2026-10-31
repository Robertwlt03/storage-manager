import Charts
import SwiftUI

/// The used space after each full scan, and the folders that grew most since the scan before. Both
/// come from the history the app keeps in its own settings.
struct HistoryCard: View {
    /// A line needs two points.
    private static let fewestPoints = 2

    @Environment(AppModel.self) private var model

    var body: some View {
        UI.Card(TextKey.historyTitle.translated) {
            if model.history.count >= Self.fewestPoints {
                UI.Note(TextKey.historyCaption.translated).padding(.top, Space.row)
                chart.padding(.vertical, Space.row)
            } else {
                UI.Note(TextKey.historyAfterNextScan.translated).padding(.vertical, Space.row)
            }
            if let growth = model.growth { grownFolders(growth) }
        }
    }

    private var chart: some View {
        Chart(model.history, id: \.date) { point in
            LineMark(
                x: .value(TextKey.historyTitle.translated, point.date),
                y: .value(TextKey.columnSize.translated, point.usedBytes)
            )
            .foregroundStyle(Theme.categoryColor(CategoryKind.media.rawValue))  // as the size chart
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel { value.as(Int64.self).map { bytes in Text(Format.bytes(bytes)) } }
            }
        }
        .staticChart()
        .frame(height: Layout.chartHeight)
    }

    @ViewBuilder private func grownFolders(_ growth: Growth) -> some View {
        Text(TextKey.grownSince.translated(with: Format.day(growth.since))).textRole(.section)
            .padding(.top, Space.row)
        if growth.folders.isEmpty {
            let smallest = Format.bytes(HistoryService.smallestListedGrowth)
            UI.Note(TextKey.nothingGrown.translated(with: smallest))
        } else {
            UI.Rows(growth.folders) { folder in
                UI.NavigationRow(
                    Paths.displayName(folder.path),
                    value: TextKey.grownBy.translated(with: Format.bytes(folder.grownBytes)),
                    action: openAction(folder.path))
            }
        }
    }

    /// Opens the folder when this scan still has it.
    private func openAction(_ path: String) -> (() -> Void)? {
        model.root.descendant(at: path).map { node in { model.open(node) } }
    }
}
