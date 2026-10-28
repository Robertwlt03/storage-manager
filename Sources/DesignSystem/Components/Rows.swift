import SwiftUI

/// What sits at the start of a row.
enum RowIcon {
    case badge(symbol: String, colorIndex: Int)  // white symbol on a coloured square, like System Settings
    case letter(String)  // a short code on a neutral square (T, C, X, 0)
    case file(String)  // the Finder icon of a path
    case preview(String)  // a Quick Look thumbnail of a path, the Finder icon until it is ready or if there is none
}

struct RowIconView: View {
    let icon: RowIcon
    var size = Layout.badgeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.badgeRadius, style: .continuous)
        switch icon {
        case .badge(let symbol, let index):
            Image(systemName: symbol).font(.system(size: size / 2, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size).background(Theme.color(index).gradient, in: shape)
        case .letter(let text):
            Text(text).font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: size, height: size).background(.quaternary, in: shape)
        case .file(let path):
            FinderService.icon(path).resizable().frame(width: size, height: size)
        case .preview(let path):
            PreviewIcon(path: path, size: size)
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
    let icon: RowIcon?
    let title: String
    var detail: String?
    var value: String?
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: Space.item) {
                if let icon { RowIconView(icon: icon) }
                VStack(alignment: .leading, spacing: Space.hairline) {
                    Text(title)
                    if let detail { Text(detail).font(.callout).foregroundStyle(.muted) }
                }
                Spacer(minLength: Space.item)
                if let value { Text(value).monospacedDigit().foregroundStyle(.muted).contentTransition(.numericText()) }
                Image(systemName: Symbols.chevron).font(.caption.weight(.semibold)).foregroundStyle(.muted)
                    .opacity(action == nil ? 0 : 1)
            }
            .contentShape(Rectangle())
            // The highlight reaches a little beyond the row without changing its layout.
            .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
            .modifier(OptionalHover(active: action != nil))
            .padding(.horizontal, -Space.s).padding(.vertical, -Space.xs)
        }
        .buttonStyle(.plain)
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
    let icon: RowIcon
    let title: String
    let subtitle: String
    var iconSize = Layout.headerIcon

    var body: some View {
        HStack(spacing: Space.item) {
            RowIconView(icon: icon, size: iconSize)
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
