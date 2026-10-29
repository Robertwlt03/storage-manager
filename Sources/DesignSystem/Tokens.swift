import SwiftUI

/// The app's components, each with its variants: type `UI.` to see them all.
enum UI {}

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

/// One icon size per role, so icons of the same role always match.
enum IconSize: CGFloat {
    case extraSmall = 10  // accents inside text: chevrons, colour dots of a legend
    case small = 16  // beside text: sidebar footer, table cells, key figures
    case medium = 26  // at the start of a row: categories, cleaner, apps
    case large = 52  // headers, sheets and tiles in the grid view
}

enum Layout {
    static let badgeRadiusShare: CGFloat = 0.23  // corner radius of coloured squares, relative to their size
    static let cardRadius: CGFloat = 16
    static let storageBarHeight: CGFloat = 22
    static let storageBarRadius: CGFloat = 5
    static let maxContentWidth: CGFloat = 900
    static let sizeColumn = (min: CGFloat(70), ideal: CGFloat(90), max: CGFloat(120))
    static let shareColumn = (min: CGFloat(90), ideal: CGFloat(150))
    static let countColumn = (min: CGFloat(60), ideal: CGFloat(80), max: CGFloat(110))
    static let percentWidth: CGFloat = 38
    /// The page never gets narrower than this; a narrower window shows the sidebar floating above the page.
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
    static let legendMax = 6
    static let legendColumns = 2
    static let chartHeight: CGFloat = 220
    static let statTileMin: CGFloat = 150
    static let statColumns = 3
    static let statMinScale = 0.7
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

/// One text style per role, built on Apple's text styles so Dynamic Type and accessibility keep working.
enum TextRole {
    case title, figure, section, body, hint, value

    var font: Font {
        switch self {
        case .title: .title2.weight(.semibold)
        case .figure: .title2.weight(.semibold).monospacedDigit()
        case .section: .headline
        case .body: .body
        case .hint: .callout
        case .value: .body.monospacedDigit()
        }
    }

    var isMuted: Bool { self == .hint || self == .value }
}

extension View {
    func textRole(_ role: TextRole) -> some View {
        font(role.font).foregroundStyle(role.isMuted ? AnyShapeStyle(Color.muted) : AnyShapeStyle(.primary))
    }
}
