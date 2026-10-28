import Charts
import SwiftUI

/// Figures and charts from the last scan, each answering one plain question. Tiles and legend entries lead to the
/// page with the details; the charts show no axes or grid lines, because every bar carries its own value.
struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.palette) private var palette = ChartPalette.colourful
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    @AppStorage(SettingsKey.largeFileMB) private var largeFileMB = LargeFileThreshold.defaultMB
    @State private var stats = Statistics()

    var body: some View {
        UI.page(.statistics) {
            if !model.hasData {
                UI.notMeasured()
            } else {
                tiles
                UI.card(Loc.statCategoriesTitle.s) {
                    UI.caption(Loc.statCategoriesCaption.s).padding(.top, Layout.rowPadding)
                    categoryChart.padding(.vertical, Layout.rowPadding)
                    UI.legend(segments) { s in node(for: s).map(model.open) }.padding(.bottom, Layout.rowPadding)
                }
                UI.card(Loc.statTypesTitle.s) {
                    UI.caption(Loc.statTypesCaption.s).padding(.top, Layout.rowPadding)
                    typeChart.padding(.vertical, Layout.rowPadding)
                }
                UI.card(Loc.statSizesTitle.s) {
                    UI.caption(Loc.statSizesCaption.s).padding(.top, Layout.rowPadding)
                    sizeChart.padding(.vertical, Layout.rowPadding)
                }
            }
        }
        .task(id: "\(model.revision)-\(largeFileMB)") {
            let computed = StatsService.compute(root: model.root)
            Motion.animate { stats = computed }
        }
    }

    // MARK: Tiles

    private var tiles: some View {
        let unused = model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count
        return UI.tiles(columns: Layout.statColumns) {
            if let v = model.startupVolume {
                UI.stat(Fmt.bytes(v.used), Loc.statUsedOf.f(Fmt.bytes(v.total)), symbol: Symbols.internalDrive) { model.pane = .overview }
            }
            UI.stat(Fmt.count(stats.files), Loc.statFiles.s, symbol: Symbols.files) { model.pane = .explorer }
            UI.stat(Fmt.count(stats.largeFiles), Loc.statLargeFilesFrom.f(Fmt.bytes(LargeFileThreshold.bytes(largeFileMB))),
                    symbol: Symbols.largeFiles) { model.pane = .largeFiles }
            UI.stat(Fmt.count(unused), Loc.statUnusedApps.s, symbol: Symbols.apps) { model.pane = .apps }
        }
    }

    // MARK: Categories

    /// Only what the scan measured; purgeable space and the remainder come from macOS, not from the scan.
    private var measured: [Category] { model.categories.filter { !CategoryKind.estimated.contains($0.kind) } }

    private var segments: [StorageSegment] {
        measured.map { StorageSegment(id: "\($0.kind)", title: $0.kind.title.s, bytes: $0.bytes, colorIndex: $0.kind.rawValue) }
    }

    private func node(for segment: StorageSegment) -> Node? { measured.first { "\($0.kind)" == segment.id }?.node }

    /// Ring of the categories; the middle names the biggest share, the legend below every colour with its size.
    private var categoryChart: some View {
        let cats = measured
        let total = max(cats.reduce(0) { $0 + $1.bytes }, 1)
        return ZStack {
            Chart(cats) { c in
                SectorMark(angle: .value(Loc.columnSize.s, c.bytes), innerRadius: .ratio(Layout.donutInner), angularInset: 1)
                    .foregroundStyle(Theme.color(c.kind.rawValue, palette))
                    .accessibilityLabel(c.kind.title.s)
                    .accessibilityValue(Fmt.bytes(c.bytes))
            }
            .chartLegend(.hidden)
            if let top = cats.first {
                VStack(spacing: 2) {
                    Text(Fmt.percent(Double(top.bytes) / Double(total))).font(.title2.weight(.semibold)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text(top.kind.title.s).foregroundStyle(.muted).multilineTextAlignment(.center)
                }
                .frame(width: Layout.chartHeight * Layout.donutInner * 0.9)
            }
        }
        .frame(height: Layout.chartHeight)
        .frame(maxWidth: .infinity)
    }

    // MARK: File types and sizes

    private var typeChart: some View {
        Chart(stats.types, id: \.name) { t in
            BarMark(x: .value(Loc.columnSize.s, t.bytes), y: .value(Loc.kind.s, t.name))
                .foregroundStyle(Theme.color(CategoryKind.apps.rawValue, palette))
                .annotation(position: .trailing) { Text(Fmt.bytes(t.bytes)).font(.caption).foregroundStyle(.muted) }
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks { AxisValueLabel() } }  // names only, no grid lines
        .frame(height: Layout.chartHeight)
    }

    /// Space per size class, with the number of files: few big files usually take more room than many small ones.
    private var sizeChart: some View {
        Chart(stats.buckets, id: \.bucket) { b in
            BarMark(x: .value(Loc.columnSize.s, b.bucket.title.s), y: .value(Loc.columnSize.s, b.bytes))
                .foregroundStyle(Theme.color(CategoryKind.media.rawValue, palette))
                .annotation(position: .top) {
                    Text(Loc.bucketValue.f(Fmt.bytes(b.bytes), Fmt.count(b.count))).font(.caption).foregroundStyle(.muted)
                        .multilineTextAlignment(.center)
                }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { AxisValueLabel() } }  // size classes only, no grid lines
        .frame(height: Layout.chartHeight)
    }
}
