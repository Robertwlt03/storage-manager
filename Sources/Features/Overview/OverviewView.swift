import Charts
import SwiftUI

/// The start page: first how much space can be freed and how, then the disk split, a short
/// summary, the history, the size classes and every category. The chart comes from the last
/// finished scan.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list

    /// Statistics exist already or are being made by the running scan.
    private var hasStatistics: Bool { model.isScanning || model.statistics != nil }

    var body: some View {
        UI.Page(.overview) {
            LayoutSwitcher(pane: .overview)
        } _: {
            FreeUpCard()
            if let startupVolume = model.startupVolume { startupDiskCard(startupVolume) }
            SummaryCard()
            HistoryCard()
            if hasStatistics { sizeClassesCard }
            // Until a scan fills them, the free-up card at the top offers to start one.
            if !model.categories.isEmpty { categories }
        }
        .smoothChanges(of: layout)
        .smoothChanges(of: model.categories.isEmpty)
    }

    // MARK: Disk

    private func startupDiskCard(_ startupVolume: VolumeInformation) -> some View {
        UI.Card {
            UI.VolumeSummary(
                startupVolume, segments: segments, canSelect: canOpen, onSelect: open)
            if startupVolume.isLow {
                UI.Note(TextKey.lowSpaceWarning.translated, .warning(symbol: Symbols.lowSpace))
                    .padding(.bottom, Space.row)
            }
        }
    }

    private var segments: [StorageSegment] {
        model.categories.map { category in
            StorageSegment(
                id: "\(category.kind)", title: category.kind.title.translated,
                bytes: category.bytes, colorIndex: category.kind.rawValue)
        }
    }

    private func node(for segment: StorageSegment) -> Node? {
        model.categories.first { category in "\(category.kind)" == segment.id }?.node
    }

    private func canOpen(_ segment: StorageSegment) -> Bool { node(for: segment) != nil }

    private func open(_ segment: StorageSegment) { node(for: segment).map(model.open) }

    // MARK: Size classes

    private var sizeClassesCard: some View {
        UI.Card(TextKey.sizeClassesTitle.translated) {
            UI.Note(TextKey.sizeClassesCaption.translated).padding(.top, Space.row)
            // Swift Charts must not redraw while a scan changes its data, so the chart waits for
            // the scan.
            if let statistics = model.statistics, !model.isScanning {
                sizeChart(statistics).padding(.vertical, Space.row)
            } else {
                UI.Placeholder(
                    .loading(
                        title: .loadingSizesTitle, detail: .loadingSizesDetail,
                        symbol: Symbols.overview)
                )
                .frame(minHeight: Layout.chartHeight).padding(.vertical, Space.row)
            }
        }
    }

    /// Space per size class, with the number of files: few big files usually take more room than
    /// many small ones.
    private func sizeChart(_ statistics: Statistics) -> some View {
        Chart(statistics.sizeClasses, id: \.sizeClass) { bar in
            BarMark(
                x: .value(TextKey.columnSize.translated, bar.sizeClass.title.translated),
                y: .value(TextKey.columnSize.translated, bar.bytes)
            )
            .foregroundStyle(Theme.categoryColor(CategoryKind.media.rawValue))
            .annotation(position: .top) {
                barLabel(bytes: bar.bytes, fileCount: bar.count)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { AxisValueLabel() } }  // size classes only, no grid lines
        .staticChart()
        .frame(height: Layout.chartHeight)
    }

    private func barLabel(bytes: Int64, fileCount: Int) -> some View {
        Text(TextKey.bucketValue.translated(with: Format.bytes(bytes), Format.count(fileCount)))
            .textRole(.caption)
            .multilineTextAlignment(.center)
    }

    // MARK: Categories

    @ViewBuilder private var categories: some View {
        if layout == .grid {
            categoryTiles
        } else {
            categoryRows
        }
    }

    @ViewBuilder private var categoryTiles: some View {
        Text(TextKey.categories.translated).textRole(.section)
            .padding(.leading, Space.extraSmall)
        UI.TileGrid(model.categories) { category in
            UI.Tile(
                icon: badge(category), title: category.kind.title.translated,
                value: Format.bytes(category.bytes)
            )
            .onTapGesture { category.node.map(model.open) }
            .accessibilityAddTraits(.isButton)
        }
    }

    private var categoryRows: some View {
        UI.Card(TextKey.categories.translated) {
            UI.Rows(model.categories) { category in
                UI.NavigationRow(
                    category.kind.title.translated, icon: badge(category),
                    value: Format.bytes(category.bytes),
                    action: category.node.map { node in { model.open(node) } })
            }
        }
    }

    private func badge(_ category: Category) -> IconKind {
        .badge(symbol: category.kind.symbol, colorIndex: category.kind.rawValue)
    }
}
