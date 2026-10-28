import SwiftUI

/// What sits at the start of a row.
enum RowIcon {
    case badge(symbol: String, colorIndex: Int)  // white symbol on a coloured square, like System Settings
    case letter(String)  // a short code on a neutral square (T, C, X, 0)
    case file(String)  // the Finder icon of a path
}

struct RowIconView: View {
    let icon: RowIcon
    var size = Layout.badgeSize
    @AppStorage(SettingsKey.palette) private var palette = ChartPalette.colourful

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.badgeRadius, style: .continuous)
        switch icon {
        case .badge(let symbol, let index):
            Image(systemName: symbol).font(.system(size: size / 2, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size).background(Theme.color(index, palette).gradient, in: shape)
        case .letter(let text):
            Text(text).font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: size, height: size).background(.quaternary, in: shape)
        case .file(let path):
            FinderService.icon(path).resizable().frame(width: size, height: size)
        }
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
            HStack(spacing: Layout.rowSpacing) {
                if let icon { RowIconView(icon: icon) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let detail { Text(detail).font(.callout).foregroundStyle(.muted) }
                }
                Spacer(minLength: Layout.rowSpacing)
                if let value { Text(value).monospacedDigit().foregroundStyle(.muted) }
                Image(systemName: Symbols.chevron).font(.caption.weight(.semibold)).foregroundStyle(.muted)
                    .opacity(action == nil ? 0 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)  // not .disabled: that would dim the text below 4.5:1
        .accessibilityElement(children: .combine)
    }
}

struct FieldItem: Identifiable {
    let label: String
    let value: String
    var id: String { label }

    init(_ label: Loc, _ value: String) { self.init(label.s, value) }
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// Label on the left, value on the right.
struct FieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.rowSpacing) {
            Text(label)
            Spacer(minLength: Layout.rowSpacing)
            Text(value).foregroundStyle(.muted).monospacedDigit().multilineTextAlignment(.trailing).textSelection(.enabled)
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
        HStack(spacing: Layout.rowSpacing) {
            RowIconView(icon: icon, size: iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.semibold)).lineLimit(2)
                Text(subtitle).foregroundStyle(.muted).lineLimit(2).textSelection(.enabled)
            }
        }
    }
}
