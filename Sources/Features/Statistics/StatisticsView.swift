import Charts
import SwiftUI

/// Figures and charts from the last scan; every chart names its colours in a legend.
struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.palette) private var palette = ChartPalette.colourful
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    @State private var stats = Statistics()

    var body: some View {
        UI.page(Loc.paneStatistics.s) {
            if !model.hasData {
                UI.card { UI.notMeasured().frame(minHeight: Layout.placeholderHeight) }
            } else {
                UI.tiles(minWidth: Layout.statTileMin) {
                    UI.stat(Fmt.count(stats.files), .statFiles, symbol: Symbols.files)
                    UI.stat(Fmt.bytes(stats.bytes), .statScanned, symbol: Symbols.internalDrive)
                    UI.stat(Fmt.count(stats.largeFiles), .statLargeFiles, symbol: Symbols.largeFiles)
                    UI.stat(Fmt.count(model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count), .statUnusedApps,
                            symbol: Symbols.apps)
                }
                UI.card(Loc.categories.s) { categoryChart.padding(.vertical, Layout.rowPadding) }
                UI.card(Loc.typesBySize.s) { typeChart.padding(.vertical, Layout.rowPadding) }
                UI.card(Loc.sizeDistribution.s) { bucketChart.padding(.vertical, Layout.rowPadding) }
                UI.note(Loc.statisticsNote.s)
            }
        }
        .task(id: model.revision) { stats = StatsService.compute(root: model.root) }
    }

    /// Ring of all categories; the legend below comes from the colour scale.
    private var categoryChart: some View {
        let cats = model.categories
        return Chart(cats) { c in
            SectorMark(angle: .value(Loc.columnSize.s, c.bytes), innerRadius: .ratio(0.6), angularInset: 1)
                .foregroundStyle(by: .value(Loc.categories.s, c.kind.title.s))
        }
        .chartForegroundStyleScale(domain: cats.map { $0.kind.title.s }, range: cats.map { Theme.color($0.kind.rawValue, palette) })
        .chartLegend(position: .trailing, alignment: .center)
        .frame(height: Layout.chartHeight)
    }

    private var typeChart: some View {
        Chart(stats.types, id: \.ext) { t in
            BarMark(x: .value(Loc.columnSize.s, t.bytes), y: .value(Loc.kind.s, t.ext))
                .foregroundStyle(Theme.color(CategoryKind.apps.rawValue, palette))
                .annotation(position: .trailing) { Text(Fmt.bytes(t.bytes)).font(.caption).foregroundStyle(.muted) }
        }
        .chartXAxis(.hidden)
        .frame(height: Layout.chartHeight)
    }

    private var bucketChart: some View {
        Chart(stats.buckets, id: \.bucket) { b in
            BarMark(x: .value(Loc.columnSize.s, b.bucket.title.s), y: .value(Loc.files.s, b.count))
                .foregroundStyle(Theme.color(CategoryKind.media.rawValue, palette))
                .annotation(position: .top) { Text(Fmt.count(b.count)).font(.caption).foregroundStyle(.muted) }
        }
        .chartYAxis(.hidden)
        .frame(height: Layout.chartHeight)
    }
}
