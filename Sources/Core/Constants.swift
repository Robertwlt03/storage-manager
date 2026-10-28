import Foundation

/// Tunable numbers of the scan, in one place.
enum ScanConfig {
    /// ponytail: folders and files below 1 MB fold into one row per folder; keeps the tree small (memory, energy).
    /// Lower it if someone needs to see tiny files.
    static let keepBytes: Int64 = 1 << 20
    static let progressInterval: TimeInterval = 0.5
    static let cancelCheckMask = 0xFFF  // check cancellation and progress every 4096 entries
    static let deleteSettleDelay: Duration = .seconds(2)  // APFS reports freed blocks with a short delay
    static let searchDebounce: Duration = .milliseconds(250)
    static let searchLimit = 500
    static let iconCacheLimit = 2_000
    static let selfTestTolerance = 0.02
    static let maxEstimatedFraction = 0.99  // an estimate never claims "done" before the scan really is
}

/// What the cleaner may remove and how old things must be.
enum CleanConfig {
    static let tempMinAgeDays = 3
    static let logMinAgeDays = 7
    static let unusedDayOptions = [30, 90, 180, 365]
    static let defaultUnusedDays = 90
}

enum LargeFileThreshold {
    static let optionsMB = [10, 50, 100, 250, 500, 1000, 5000]
    static let defaultMB = 500
    static func bytes(_ mb: Int) -> Int64 { Int64(mb) * 1_000_000 }
}

/// The spacing scale: every gap in the app is one of these steps on Apple's 4-point grid,
/// and each kind of gap always uses the same step.
enum Space {
    static let hairline: CGFloat = 2  // title and subtitle of one item
    static let xs: CGFloat = 4  // headings to their card, tight groups
    static let s: CGFloat = 8  // inside a row: icon to text, dot to label; row padding; card title to card
    static let m: CGFloat = 12  // between the parts of a row
    static let l: CGFloat = 16  // between cards and sections; inside cards
    static let xl: CGFloat = 24  // page margins

    static let page = xl
    static let section = l
    static let card = l
    static let row = s
    static let item = m
}

/// Hidden stand-in text that keeps the space of a value still being calculated; it is never shown or read.
enum Placeholder {
    static let figure = "0.000.000"
}

enum WindowID {
    static let main = "main"
}

enum Layout {
    static let cardRadius: CGFloat = 16
    static let badgeRadius: CGFloat = 6
    static let badgeSize: CGFloat = 26
    static let headerIcon: CGFloat = 48
    static let sheetIcon: CGFloat = 56
    static let listIcon: CGFloat = 16
    static let storageBarHeight: CGFloat = 22
    static let storageBarRadius: CGFloat = 5
    static let maxContentWidth: CGFloat = 900
    static let sizeColumn = (min: CGFloat(70), ideal: CGFloat(90), max: CGFloat(120))
    static let shareColumn = (min: CGFloat(90), ideal: CGFloat(150))
    static let countColumn = (min: CGFloat(60), ideal: CGFloat(80), max: CGFloat(110))
    static let percentWidth: CGFloat = 38
    /// The page never gets narrower than this; with the sidebar open the window has to make room for both.
    static let pageMinWidth: CGFloat = 600
    static let minWindowWidth: CGFloat = pageMinWidth
    /// Room for the sidebar and the page side by side; below it the sidebar closes by itself, like in Mail.
    static let sidebarCollapseWidth: CGFloat = sidebarIdeal + pageMinWidth
    static let minWindowHeight: CGFloat = 560
    static let sidebarIdeal: CGFloat = 230
    static let settingsWidth: CGFloat = 520
    static let sheetWidth: CGFloat = 560
    static let sheetHeight: CGFloat = 600
    static let folderListHeight: CGFloat = 90
    static let settingsHeight: CGFloat = 330
    static let placeholderHeight: CGFloat = 320
    static let backdropOpacity = 0.16
    static let gridTile: CGFloat = 170
    static let gridIcon: CGFloat = 52
    static let legendDot: CGFloat = 10
    static let legendMax = 6
    static let legendColumns = 2
    static let chartHeight: CGFloat = 220
    static let statTileMin: CGFloat = 150
    static let statColumns = 3
    static let popoverWidth: CGFloat = 340
    static let headerHeight: CGFloat = 28
    static let fillShare = 0.72
}

/// SF Symbol names used across the app.
enum Symbols {
    static let overview = "chart.bar.xaxis"
    static let cleaner = "sparkles"
    static let apps = "app.badge.clock"
    static let settings = "gearshape"
    static let list = "list.bullet"
    static let grid = "square.grid.2x2"
    static let trashApp = "trash"
    static let files = "doc.on.doc"
    static let speaker = "speaker.wave.2"
    static let summary = "text.bubble"
    static let sidebar = "sidebar.left"
    static let explorer = "folder"
    static let largeFiles = "doc.viewfinder"
    static let temp = "hourglass"
    static let copies = "checkmark.seal"
    static let internalDrive = "internaldrive"
    static let externalDrive = "externaldrive"
    static let volumeGone = "externaldrive.badge.xmark"
    static let rescan = "arrow.clockwise"
    static let chevron = "chevron.right"
    static let rest = "ellipsis.circle"
    static let info = "info.circle"
    static let finder = "folder"
    static let measure = "gauge.with.dots.needle.33percent"
    static let search = "magnifyingglass"
    static let running = "play.circle.fill"
    static let stopped = "stop.circle"
    static let success = "checkmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let unknownApp = "app.dashed"
    static let add = "plus"
    static let remove = "minus"
}

enum SystemLinks {
    static let fullDiskAccess = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
