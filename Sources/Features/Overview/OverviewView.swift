import Charts
import SwiftUI

/// The start page: key figures, the disk split, a short summary, the size classes and every category.
/// Figures and the chart come from the last finished scan; while a scan runs their cards stay in place with a
/// spinner where the values go, so nothing jumps around and nothing stale can be clicked.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    @AppStorage(SettingsKey.largeFileMB) private var largeFileMB = LargeFileThreshold.defaultMB

    var body: some View {
        UI.page(.overview) {
            if model.scanning || model.stats != nil { tiles }
            if let v = model.startupVolume {
                UI.card {
                    UI.volume(v, segments: segments, canSelect: { node(for: $0) != nil }) { node(for: $0).map(model.open) }
                }
            }
            SummaryCard()
            if model.scanning || model.stats != nil {
                UI.card(Loc.statSizesTitle.s) {
                    UI.caption(Loc.statSizesCaption.s).padding(.top, Space.row)
                    // Swift Charts must not redraw while a scan changes its data, so the chart waits for the scan.
                    if let stats = model.stats, !model.scanning { sizeChart(stats).padding(.vertical, Space.row) } else {
                        UI.loading(.loadingSizesTitle, .loadingSizesDetail, symbol: Symbols.overview)
                            .frame(minHeight: Layout.chartHeight).padding(.vertical, Space.row)
                    }
                }
            }
            if model.categories.isEmpty {
                UI.notMeasuredCard(Loc.categories.s)
            } else if layout == .grid {
                Text(Loc.categories.s).font(.headline).padding(.leading, Space.xs)
                UI.grid(model.categories) { c in
                    UI.tile(icon: badge(c), title: c.kind.title.s, value: Fmt.bytes(c.bytes))
                        .onTapGesture { c.node.map(model.open) }
                }
            } else {
                UI.card(Loc.categories.s) {
                    UI.rows(model.categories) { c in
                        UI.navRow(c.kind.title.s, icon: badge(c), value: Fmt.bytes(c.bytes), action: c.node.map { n in { model.open(n) } })
                    }
                }
            }
        }
        .smoothChanges(of: layout)
        .smoothChanges(of: model.categories.isEmpty)
        .smoothChanges(of: model.scanning)
        .onChange(of: largeFileMB) { if !model.scanning { model.refreshStats() } }
    }

    // MARK: Key figures

    /// Each figure leads to the page with the details; the used space is already in the disk card below.
    private var tiles: some View {
        let unused = model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count
        let loading = model.scanning || model.stats == nil
        func figure(_ n: Int?) -> String { loading ? Placeholder.figure : n.map(Fmt.count) ?? Placeholder.figure }
        return UI.tiles(columns: Layout.statColumns) {
            UI.stat(figure(model.stats?.files), Loc.statFiles.s, symbol: Symbols.files, loading: loading) { model.pane = .explorer }
            UI.stat(figure(model.stats?.largeFiles), Loc.statLargeFilesFrom.f(Fmt.bytes(LargeFileThreshold.bytes(largeFileMB))),
                    symbol: Symbols.largeFiles, loading: loading) { model.pane = .largeFiles }
            UI.stat(figure(unused), Loc.statUnusedApps.s, symbol: Symbols.apps, loading: loading) { model.pane = .apps }
        }
    }

    // MARK: Size classes

    /// Space per size class, with the number of files: few big files usually take more room than many small ones.
    private func sizeChart(_ stats: Statistics) -> some View {
        Chart(stats.buckets, id: \.bucket) { b in
            BarMark(x: .value(Loc.columnSize.s, b.bucket.title.s), y: .value(Loc.columnSize.s, b.bytes))
                .foregroundStyle(Theme.color(CategoryKind.media.rawValue))
                .annotation(position: .top) {
                    Text(Loc.bucketValue.f(Fmt.bytes(b.bytes), Fmt.count(b.count))).font(.caption).foregroundStyle(.muted)
                        .multilineTextAlignment(.center)
                }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { AxisValueLabel() } }  // size classes only, no grid lines
        .staticChart()
        .frame(height: Layout.chartHeight)
    }

    // MARK: Categories

    private func node(for segment: StorageSegment) -> Node? { model.categories.first { "\($0.kind)" == segment.id }?.node }

    private func badge(_ c: Category) -> RowIcon { .badge(symbol: c.kind.symbol, colorIndex: c.kind.rawValue) }

    private var segments: [StorageSegment] {
        model.categories.map { StorageSegment(id: "\($0.kind)", title: $0.kind.title.s, bytes: $0.bytes, colorIndex: $0.kind.rawValue) }
    }
}
