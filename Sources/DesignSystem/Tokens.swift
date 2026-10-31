import SwiftUI

/// The app's components, each with its variants: type `UI.` to see them all.
enum UI {}

/// The spacing scale: every gap in the app is one of these steps on Apple's 4-point grid,
/// and each kind of gap always uses the same step.
enum Space {
    static let hairline: CGFloat = 2  // title and subtitle of one item
    static let extraSmall: CGFloat = 4  // headings to their card, tight groups
    /// Inside a row: icon to text, dot to label; row padding; card title to card.
    static let small: CGFloat = 8
    static let medium: CGFloat = 12  // between the parts of a row
    static let large: CGFloat = 16  // between cards and sections; inside cards
    static let extraLarge: CGFloat = 24  // page margins

    static let page = extraLarge
    static let section = large
    static let card = large
    static let row = small
    static let item = medium
}

/// One icon size per role, so icons of the same role always match.
enum IconSize: CGFloat {
    case extraSmall = 10  // accents inside text: chevrons, color dots of a legend
    case small = 16  // beside text: sidebar footer, table cells, key figures
    case medium = 26  // at the start of a row: categories, cleaner, apps
    case large = 52  // headers, sheets and tiles in the grid view
}

enum Layout {
    /// Corner radius of colored squares, relative to their size.
    static let badgeRadiusShare: CGFloat = 0.23
    /// The symbol or letter on a colored square fills half of it.
    static let badgeContentShare: CGFloat = 0.5
    static let cardRadius: CGFloat = 16
    static let storageBarHeight: CGFloat = 22
    static let storageBarRadius: CGFloat = 5
    static let maximumContentWidth: CGFloat = 900
    static let sizeColumn = (min: CGFloat(70), ideal: CGFloat(90), max: CGFloat(120))
    static let shareColumn = (min: CGFloat(90), ideal: CGFloat(150))
    static let countColumn = (min: CGFloat(60), ideal: CGFloat(80), max: CGFloat(110))
    static let percentColumnWidth: CGFloat = 38
    /// The page never gets narrower than this; a narrower window shows the sidebar floating above
    /// the page.
    static let pageMinimumWidth: CGFloat = 600
    static let minimumWindowWidth: CGFloat = pageMinimumWidth
    /// Room for the sidebar and the page side by side; below it the sidebar closes by itself, like
    /// in Mail.
    static let sidebarCollapseWidth: CGFloat = sidebarIdealWidth + pageMinimumWidth
    static let minimumWindowHeight: CGFloat = 560
    static let sidebarIdealWidth: CGFloat = 230
    static let settingsWidth: CGFloat = 520
    static let sheetWidth: CGFloat = 560
    static let sheetHeight: CGFloat = 600
    static let folderListHeight: CGFloat = 90
    static let placeholderHeight: CGFloat = 320
    static let gridTileSize: CGFloat = 170
    static let legendMaximumEntries = 6
    static let legendColumns = 2
    static let chartHeight: CGFloat = 220
    static let keyFigureColumns = 3
    static let keyFigureMinimumScale = 0.7
    static let popoverWidth: CGFloat = 340
    static let headerHeight: CGFloat = 28
    static let placeholderPageShare = 0.72
    /// Titles and labels that may wrap show at most this many lines.
    static let maximumWrappedLines = 2
}

/// How much of a view shows: fully, or not at all while it keeps its place.
enum Opacity {
    static let full = 1.0
    static let hidden = 0.0
}

/// A share of a whole, from nothing to everything.
enum Fraction {
    static let nothing = 0.0
    static let whole = 1.0

    /// Keeps a share between nothing and the whole, as progress bars expect.
    static func clamp(_ share: Double) -> Double { min(max(share, nothing), whole) }
}

/// SF Symbol names used across the app.
nonisolated enum Symbols {
    static let overview = "chart.bar.xaxis"
    static let cleaner = "sparkles"
    static let apps = "app.badge.clock"
    static let settings = "gearshape"
    static let list = "list.bullet"
    static let grid = "square.grid.2x2"
    static let files = "doc.on.doc"
    static let summary = "text.bubble"
    static let sidebar = "sidebar.left"
    static let explorer = "folder"
    static let largeFiles = "doc.viewfinder"
    static let temporaryArea = "hourglass"
    static let copies = "checkmark.seal"
    static let rings = "circle.circle"
    static let duplicates = "plus.square.on.square"
    static let internalDrive = "internaldrive"
    static let lowSpace = "exclamationmark.triangle"
    static let externalDrive = "externaldrive"
    static let volumeGone = "externaldrive.badge.xmark"
    static let rescan = "arrow.clockwise"
    static let chevron = "chevron.right"
    static let otherItems = "ellipsis.circle"
    static let information = "info.circle"
    static let measure = "gauge.with.dots.needle.33percent"
    static let search = "magnifyingglass"
    static let running = "play.circle.fill"
    static let stopped = "stop.circle"
    static let success = "checkmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let add = "plus"
    static let remove = "minus"

    // Storage categories; temporary files and the system reuse the symbols of their pages.
    static let appCollection = "square.grid.2x2"
    static let documents = "doc.text"
    static let downloads = "arrow.down.circle"
    static let media = "photo.on.rectangle"
    static let iCloud = "icloud"
    static let mail = "envelope"
    static let developer = "hammer"
    static let caches = "archivebox"
    static let appData = "shippingbox"
    static let trash = "trash"
    static let user = "person.crop.circle"
    static let library = "gearshape"
    static let otherFiles = "folder"
    static let purgeable = "arrow.3.trianglepath"
}

/// One text style per role, built on Apple's text styles so Dynamic Type and accessibility keep
/// working.
enum TextRole {
    case title, figure, section, body, label, hint, value, caption

    var font: Font {
        switch self {
        case .title: .title2.weight(.semibold)
        case .figure: .title2.weight(.semibold).monospacedDigit()
        case .section: .headline
        case .body: .body
        case .label, .hint: .callout
        case .value: .body.monospacedDigit()
        case .caption: .caption
        }
    }

    var isMuted: Bool { [.hint, .value, .caption].contains(self) }
}

extension View {
    func textRole(_ role: TextRole) -> some View {
        font(role.font)
            .foregroundStyle(
                role.isMuted ? AnyShapeStyle(Theme.muted.color) : AnyShapeStyle(.primary))
    }
}
