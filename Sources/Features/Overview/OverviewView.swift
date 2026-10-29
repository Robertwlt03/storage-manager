import Charts
import SwiftUI

/// The start page: key figures, the disk split, a short summary, the size classes and every category.
/// Figures and the chart come from the last finished scan.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    @AppStorage(SettingsKey.largeFileMB) private var largeFileMegabytes =
        LargeFileThreshold.defaultMB

    /// Statistics exist already or are being made by the running scan.
    private var hasStatistics: Bool { model.scanning || model.stats != nil }

    var body: some View {
        UI.Page(.overview) {
            if hasStatistics { keyFigures }
            if let startupVolume = model.startupVolume { startupDiskCard(startupVolume) }
            SummaryCard()
            if hasStatistics { sizeClassesCard }
            categories
        }
        .smoothChanges(of: layout)
        .smoothChanges(of: model.categories.isEmpty)
        .onChange(of: largeFileMegabytes) { if !model.scanning { model.refreshStats() } }
    }

    // MARK: Key figures

    private var isLoadingFigures: Bool { model.scanning || model.stats == nil }

    /// Each figure leads to the page with the details; the used space is already in the disk card below.
    private var keyFigures: some View {
        let unusedApps = model.apps.filter { app in
            AppUsageService.isUnused(app, days: unusedDays)
        }
        let largeFileThreshold = Format.bytes(LargeFileThreshold.bytes(largeFileMegabytes))
        return UI.FixedGrid(columns: Layout.statColumns) {
            UI.KeyFigure(
                figureText(model.stats?.files), TextKey.figureFiles.translated,
                symbol: Symbols.files, loading: isLoadingFigures
            ) { model.pane = .explorer }
            UI.KeyFigure(
                figureText(model.stats?.largeFiles),
                TextKey.figureLargeFilesFrom.translated(with: largeFileThreshold),
                symbol: Symbols.largeFiles, loading: isLoadingFigures
            ) { model.pane = .largeFiles }
            UI.KeyFigure(
                figureText(unusedApps.count), TextKey.figureUnusedApps.translated,
                symbol: Symbols.apps, loading: isLoadingFigures
            ) { model.pane = .apps }
        }
    }

    private func figureText(_ count: Int?) -> String {
        guard !isLoadingFigures, let count else { return StandInText.figure }
        return Format.count(count)
    }

    // MARK: Disk

    private func startupDiskCard(_ startupVolume: VolumeInfo) -> some View {
        UI.Card {
            UI.VolumeSummary(
                startupVolume, segments: segments, canSelect: canOpen, onSelect: open)
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
            // Swift Charts must not redraw while a scan changes its data, so the chart waits for the scan.
            if let stats = model.stats, !model.scanning {
                sizeChart(stats).padding(.vertical, Space.row)
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

    /// Space per size class, with the number of files: few big files usually take more room than many small ones.
    private func sizeChart(_ stats: Statistics) -> some View {
        Chart(stats.buckets, id: \.bucket) { sizeClass in
            BarMark(
                x: .value(TextKey.columnSize.translated, sizeClass.bucket.title.translated),
                y: .value(TextKey.columnSize.translated, sizeClass.bytes)
            )
            .foregroundStyle(Theme.color(CategoryKind.media.rawValue))
            .annotation(position: .top) {
                barLabel(bytes: sizeClass.bytes, fileCount: sizeClass.count)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { AxisValueLabel() } }  // size classes only, no grid lines
        .staticChart()
        .frame(height: Layout.chartHeight)
    }

    private func barLabel(bytes: Int64, fileCount: Int) -> some View {
        Text(TextKey.bucketValue.translated(with: Format.bytes(bytes), Format.count(fileCount)))
            .font(.caption)
            .foregroundStyle(.muted)
            .multilineTextAlignment(.center)
    }

    // MARK: Categories

    @ViewBuilder private var categories: some View {
        if model.categories.isEmpty {
            UI.Card(TextKey.categories.translated) { UI.Placeholder(.notMeasured, in: .card) }
        } else if layout == .grid {
            Text(TextKey.categories.translated).textRole(.section)
                .padding(.leading, Space.extraSmall)
            UI.TileGrid(model.categories) { category in
                UI.Tile(
                    icon: badge(category), title: category.kind.title.translated,
                    value: Format.bytes(category.bytes)
                )
                .onTapGesture { category.node.map(model.open) }
            }
        } else {
            UI.Card(TextKey.categories.translated) {
                UI.Rows(model.categories) { category in
                    UI.NavRow(
                        category.kind.title.translated, icon: badge(category),
                        value: Format.bytes(category.bytes),
                        action: category.node.map { node in { model.open(node) } })
                }
            }
        }
    }

    private func badge(_ category: Category) -> IconKind {
        .badge(symbol: category.kind.symbol, colorIndex: category.kind.rawValue)
    }
}
