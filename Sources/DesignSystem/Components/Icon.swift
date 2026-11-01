import SwiftUI

/// What an icon shows; how big it is comes from `IconSize`. Icons always stand beside a text that
/// says what they mean, so VoiceOver skips them instead of reading a symbol's technical name.
/// While the window is in the background (a dialog or another window in front), symbols and badges
/// turn gray like the sidebar's; Finder icons and previews keep their colors, as in the Finder.
enum IconKind {
    case symbol(String)
    case accent(String)  // a symbol in the accent color, like the sidebar's
    case dot(Color)
    /// A white symbol on a colored square, like System Settings.
    case badge(symbol: String, colorIndex: Int)
    case letter(String)  // a short sign on a neutral square, such as "…" for an unnamed entry
    case file(String)  // the Finder icon of a path
    case preview(String)  // the Quick Look thumbnail of a path, the Finder icon until it is ready
}

extension UI {
    /// Every icon fills the same square for its size, so a wide grid symbol and a round arrow look
    /// equally big.
    struct Icon: View {
        let kind: IconKind
        var size = IconSize.medium
        @Environment(\.controlActiveState) private var activeState

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
                symbol(name, side: side).inBackgroundGray(isInBackground)
            case .accent(let name):
                symbol(name, side: side).foregroundStyle(accentStyle)
            case .dot(let color):
                Circle().fill(color).frame(width: side, height: side)
            case .badge(let name, let index):
                Image(systemName: name).resizable().scaledToFit().fontWeight(.semibold)
                    .accessibilityHidden(true)
                    .foregroundStyle(Theme.badgeSymbol)
                    .frame(width: badgeContent, height: badgeContent)
                    .frame(width: side, height: side)
                    .background(badgeColor(index).gradient, in: square)
            case .letter(let text):
                Text(text).font(.system(size: badgeContent, weight: .semibold, design: .monospaced))
                    .frame(width: side, height: side).background(.quaternary, in: square)
            case .file(let path):
                Image(nsImage: PreviewService.finderIcon(path)).resizable()
                    .frame(width: side, height: side)
                    .accessibilityHidden(true)
            case .preview(let path):
                PreviewIcon(path: path, side: side)
            }
        }

        /// Not the key window: the sidebar grays its symbols then too, also while the Settings
        /// window or a dialog is in front.
        private var isInBackground: Bool { activeState != .key }

        private func symbol(_ name: String, side: CGFloat) -> some View {
            Image(systemName: name).resizable().scaledToFit().frame(width: side, height: side)
                .accessibilityHidden(true)
        }

        private var accentStyle: AnyShapeStyle {
            isInBackground ? AnyShapeStyle(Theme.inBackground) : AnyShapeStyle(.tint)
        }

        private func badgeColor(_ index: Int) -> Color {
            isInBackground ? Theme.inBackground : Theme.categoryColor(index)
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
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: thumbnail ?? PreviewService.finderIcon(path))
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
            .task(id: path) {
                thumbnail = await PreviewService.thumbnail(path, size: side, scale: displayScale)
            }
    }
}

extension View {
    /// Gray instead of the color given further out, while the window is in the background.
    @ViewBuilder fileprivate func inBackgroundGray(_ isInBackground: Bool) -> some View {
        if isInBackground { foregroundStyle(Theme.inBackground) } else { self }
    }
}
