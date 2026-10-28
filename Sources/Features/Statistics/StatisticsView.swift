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
                UI.tiles(columns: Layout.statColumns) {
                    UI.stat(Fmt.count(stats.files), .statFiles, symbol: Symbols.files)
                    UI.stat(Fmt.bytes(stats.bytes), .statScanned, symbol: Symbols.internalDrive)
                    UI.stat(Fmt.count(stats.largeFiles), .statLargeFiles, symbol: Symbols.largeFiles)
                    UI.stat(Fmt.count(model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count), .statUnusedApps,
                            symbol: Symbols.apps)
                }
                UI.card(Loc.categories.s) {
                    categoryChart.padding(.vertical, Layout.rowPadding)
                    UI.legend(segments).padding(.bottom, Layout.rowPadding)
                }
                UI.card(Loc.typesBySize.s) { typeChart.padding(.vertical, Layout.rowPadding) }
                UI.card(Loc.sizeDistribution.s) { bucketChart.padding(.vertical, Layout.rowPadding) }
                UI.note(Loc.statisticsNote.s)
            }
        }
        .task(id: model.revision) { stats = StatsService.compute(root: model.root) }
    }

    /// Only what the scan measured; purgeable space and the remainder come from macOS, not from the scan.
    private var measured: [Category] { model.categories.filter { !CategoryKind.estimated.contains($0.kind) } }

    private var segments: [StorageSegment] {
        measured.map { StorageSegment(id: "\($0.kind)", title: $0.kind.title.s, bytes: $0.bytes, colorIndex: $0.kind.rawValue) }
    }

    /// Ring of all categories with the total in the middle; the legend below names every colour with its size.
    private var categoryChart: some View {
        let cats = measured
        return ZStack {
            Chart(cats) { c in
                SectorMark(angle: .value(Loc.columnSize.s, c.bytes), innerRadius: .ratio(Layout.donutInner), angularInset: 1)
                    .foregroundStyle(Theme.color(c.kind.rawValue, palette))
                    .accessibilityLabel(c.kind.title.s)
                    .accessibilityValue(Fmt.bytes(c.bytes))
            }
            .chartLegend(.hidden)
            VStack(spacing: 2) {
                Text(Fmt.bytes(model.root.bytes)).font(.title2.weight(.semibold)).monospacedDigit()
                Text(Loc.statScanned.s).foregroundStyle(.muted)  // clones count in full, so "used" would overstate
            }
        }
        .frame(height: Layout.chartHeight)
        .frame(maxWidth: .infinity)
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
