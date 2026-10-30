import SwiftUI

/// What an icon shows; how big it is comes from `IconSize`.
enum IconKind {
    case symbol(String)
    case dot(Color)
    /// A white symbol on a colored square, like System Settings.
    case badge(symbol: String, colorIndex: Int)
    case letter(String)  // a short code on a neutral square: T, C, X, 0
    case file(String)  // the Finder icon of a path
    case preview(String)  // the Quick Look thumbnail of a path, the Finder icon until it is ready
}

extension UI {
    /// Every icon fills the same square for its size, so a wide grid symbol and a round arrow look
    /// equally big.
    struct Icon: View {
        let kind: IconKind
        var size = IconSize.medium

        init(_ kind: IconKind, size: IconSize = .medium) {
            self.kind = kind
            self.size = size
        }

        var body: some View {
            let side = size.rawValue
            let badgeContent = side * Layout.badgeContentShare
            let square = RoundedRectangle(
                cornerRadius: side * Layout.badgeRadiusShare, style: .continuous)
            switch kind {
            case .symbol(let name):
                Image(systemName: name).resizable().scaledToFit().frame(width: side, height: side)
            case .dot(let color):
                Circle().fill(color).frame(width: side, height: side)
            case .badge(let name, let index):
                Image(systemName: name).resizable().scaledToFit().fontWeight(.semibold)
                    .foregroundStyle(Theme.badgeSymbol)
                    .frame(width: badgeContent, height: badgeContent)
                    .frame(width: side, height: side)
                    .background(Theme.categoryColor(index).gradient, in: square)
            case .letter(let text):
                Text(text).font(.system(size: badgeContent, weight: .semibold, design: .monospaced))
                    .frame(width: side, height: side).background(.quaternary, in: square)
            case .file(let path):
                FinderService.icon(path).resizable().frame(width: side, height: side)
            case .preview(let path):
                PreviewIcon(path: path, side: side)
            }
        }
    }

    /// The small arrow at the end of anything that leads somewhere.
    struct Chevron: View {
        var body: some View {
            Icon(.symbol(Symbols.chevron), size: .extraSmall).fontWeight(.semibold)
                .foregroundStyle(.muted)
        }
    }
}

/// Only icons on screen ask Quick Look for a thumbnail.
private struct PreviewIcon: View {
    let path: String
    let side: CGFloat
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? FinderService.iconImage(path))
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .task(id: path) { thumbnail = await PreviewService.thumbnail(path, size: side) }
    }
}
