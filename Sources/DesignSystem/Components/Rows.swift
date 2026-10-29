import SwiftUI

/// Every icon of the app: what it shows. How big it is comes from `IconSize`, so all icons of one size look alike.
enum Icon {
    case symbol(String)  // an SF Symbol in the surrounding colour
    case badge(symbol: String, colorIndex: Int)  // white symbol on a coloured square, like System Settings
    case letter(String)  // a short code on a neutral square (T, C, X, 0)
    case file(String)  // the Finder icon of a path
    case preview(String)  // a Quick Look thumbnail of a path, the Finder icon until it is ready or if there is none
}

/// One component for all icons: each kind fills the same square of its size. SF Symbols differ in shape (a wide grid,
/// a round arrow, a gear), so they are fitted into the square instead of being drawn at a font size.
struct IconView: View {
    let icon: Icon
    var size = IconSize.medium

    var body: some View {
        let side = size.rawValue
        let shape = RoundedRectangle(cornerRadius: side * Layout.badgeRadiusShare, style: .continuous)
        switch icon {
        case .symbol(let symbol):
            Image(systemName: symbol).resizable().scaledToFit().frame(width: side, height: side)
        case .badge(let symbol, let index):
            Image(systemName: symbol).resizable().scaledToFit().fontWeight(.semibold).foregroundStyle(.white)
                .frame(width: side / 2, height: side / 2)
                .frame(width: side, height: side).background(Theme.color(index).gradient, in: shape)
        case .letter(let text):
            Text(text).font(.system(size: side / 2, weight: .semibold, design: .monospaced))
                .frame(width: side, height: side).background(.quaternary, in: shape)
        case .file(let path):
            FinderService.icon(path).resizable().frame(width: side, height: side)
        case .preview(let path):
            PreviewIcon(path: path, size: side)
        }
    }
}

/// Starts with the Finder icon and swaps in the thumbnail once Quick Look has it; only tiles on screen ask for one.
private struct PreviewIcon: View {
    let path: String
    let size: CGFloat
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? FinderService.iconImage(path))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .task(id: path) { thumbnail = await PreviewService.thumbnail(path, size: size) }
    }
}

/// Icon, title, optional detail line, value and – if there is an action – a chevron.
struct NavRow: View {
    let icon: Icon?
    let title: String
    var detail: String?
    var value: String?
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: Space.item) {
                if let icon { IconView(icon: icon) }
                VStack(alignment: .leading, spacing: Space.hairline) {
                    Text(title)
                    if let detail { Text(detail).font(.callout).foregroundStyle(.muted) }
                }
                Spacer(minLength: Space.item)
                if let value { Text(value).monospacedDigit().foregroundStyle(.muted).contentTransition(.numericText()) }
                Chevron()
                    .opacity(action == nil ? 0 : 1)
            }
            .contentShape(Rectangle())
            // The highlight reaches a little beyond the row without changing its layout.
            .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
            .modifier(OptionalHover(active: action != nil))
            .padding(.horizontal, -Space.s).padding(.vertical, -Space.xs)
        }
        .appButton(.content)
        .allowsHitTesting(action != nil)  // not .disabled: that would dim the text below 4.5:1
        .accessibilityElement(children: .combine)
    }
}

struct FieldItem: Identifiable {
    let label: String
    let value: String?  // nil while it is still being calculated
    var id: String { label }

    init(_ label: Loc, _ value: String?) { self.init(label.s, value) }
    init(_ label: String, _ value: String?) {
        self.label = label
        self.value = value
    }
}

/// Label on the left, value on the right.
struct FieldRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.item) {
            Text(label)
            Spacer(minLength: Space.item)
            Text(value ?? Placeholder.figure).foregroundStyle(.muted).monospacedDigit().multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .calculating(value == nil, alignment: .trailing)
        }
    }
}

/// Large icon with title and subtitle, used at the top of volume cards and the info sheet.
struct HeaderRow: View {
    let icon: Icon
    let title: String
    let subtitle: String
    var iconSize = IconSize.large

    var body: some View {
        HStack(spacing: Space.item) {
            IconView(icon: icon, size: iconSize)
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(title).font(.title2.weight(.semibold)).lineLimit(2)
                Text(subtitle).foregroundStyle(.muted).lineLimit(2).textSelection(.enabled)
            }
        }
    }
}

/// Hover highlight only for rows that lead somewhere.
private struct OptionalHover: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.hoverHighlight() } else { content }
    }
}

/// The small arrow at the end of anything that leads somewhere: rows, tiles and legend entries.
struct Chevron: View {
    var body: some View { Image(systemName: Symbols.chevron).font(.caption.weight(.semibold)).foregroundStyle(.muted) }
}
