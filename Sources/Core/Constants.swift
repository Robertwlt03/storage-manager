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
    static let selfTestTolerance = 0.02
}

enum LargeFileThreshold {
    static let optionsMB = [10, 50, 100, 250, 500, 1000, 5000]
    static let defaultMB = 500
    static func bytes(_ mb: Int) -> Int64 { Int64(mb) * 1_000_000 }
}

enum Layout {
    static let spacing: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let pagePadding: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let rowPadding: CGFloat = 9
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
    static let minWindowWidth: CGFloat = 860
    static let minWindowHeight: CGFloat = 560
    static let sidebarMin: CGFloat = 210
    static let sidebarIdeal: CGFloat = 230
    static let settingsWidth: CGFloat = 520
    static let sheetWidth: CGFloat = 560
    static let sheetHeight: CGFloat = 600
    static let folderListHeight: CGFloat = 90
    static let settingsGeneralHeight: CGFloat = 220
    static let settingsAppearanceHeight: CGFloat = 290
    static let settingsScanHeight: CGFloat = 440
    static let placeholderHeight: CGFloat = 320
    static let backdropOpacity = 0.16
}

/// SF Symbol names used across the app.
enum Symbols {
    static let overview = "chart.bar.xaxis"
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
    static let tabGeneral = "gearshape"
    static let tabAppearance = "paintbrush"
    static let tabScanning = "gauge.with.dots.needle.50percent"
}

enum SystemLinks {
    static let fullDiskAccess = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
