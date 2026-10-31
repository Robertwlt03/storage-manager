import SwiftUI
import WidgetKit

/// How much space the Mac has left, on the desktop or in Notification Center. The widget reads the
/// startup volume itself, because the sandbox macOS gives every widget keeps it from the app's
/// data.
struct FreeSpaceWidget: Widget {
    private static let kind = "FreeSpace"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SpaceProvider()) { entry in
            FreeSpaceView(entry: entry).containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(WidgetText.widgetName.translated)
        .description(WidgetText.widgetDescription.translated)
        .supportedFamilies([.systemSmall])
    }
}

/// The startup volume's capacity and what is available, as Finder counts it.
nonisolated struct VolumeSpace {
    let availableBytes: Int64
    let totalBytes: Int64

    /// Between none and all, even when the available space briefly reads above the capacity.
    var usedShare: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(totalBytes - availableBytes) / Double(totalBytes), 0), 1)
    }

    static func startup() -> VolumeSpace? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? URL(filePath: "/").resourceValues(forKeys: keys),
            let total = values.volumeTotalCapacity,
            let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return VolumeSpace(availableBytes: available, totalBytes: Int64(total))
    }
}

nonisolated struct SpaceEntry: TimelineEntry {
    let date: Date
    let space: VolumeSpace?
}

/// Reads the space now and again after a quarter of an hour; it changes slowly.
nonisolated struct SpaceProvider: TimelineProvider {
    private static let refreshMinutes = 15

    static func entry() -> SpaceEntry { SpaceEntry(date: Date(), space: .startup()) }

    func placeholder(in _: Context) -> SpaceEntry { Self.entry() }

    func getSnapshot(in _: Context, completion: @escaping (SpaceEntry) -> Void) {
        completion(Self.entry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SpaceEntry>) -> Void) {
        let entry = Self.entry()
        let next =
            Calendar.current.date(byAdding: .minute, value: Self.refreshMinutes, to: entry.date)
            ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct FreeSpaceView: View {
    let entry: SpaceEntry

    private static let symbol = "internaldrive"
    private static let smallestScale = 0.6
    private static let barHeight: CGFloat = 6

    var body: some View {
        if let space = entry.space {
            content(space)
        } else {
            Text(WidgetText.widgetUnreadable.translated).widgetText(.label)
        }
    }

    private func content(_ space: VolumeSpace) -> some View {
        VStack(alignment: .leading) {
            Label(WidgetText.widgetName.translated, systemImage: Self.symbol)
                .widgetText(.label)
            Spacer(minLength: 0)
            Text(bytes(space.availableBytes))
                .widgetText(.figure).lineLimit(1).minimumScaleFactor(Self.smallestScale)
            Text(WidgetText.widgetAvailable.translated).widgetText(.label)
            usedBar(space.usedShare)
            Text(WidgetText.widgetOfTotal.translated(with: bytes(space.totalBytes)))
                .widgetText(.note)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// The used share as a bar, drawn in SwiftUI so it looks the same everywhere.
    private func usedBar(_ share: Double) -> some View {
        Capsule().fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(.tint).frame(width: geometry.size.width * share)
                }
            }
            .frame(height: Self.barHeight)
            .accessibilityHidden(true)  // the texts say the same
    }

    private func bytes(_ count: Int64) -> String { count.formatted(.byteCount(style: .file)) }
}
