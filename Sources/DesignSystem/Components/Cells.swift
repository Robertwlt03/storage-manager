import SwiftUI

extension UI {
    /// Finder icon and name.
    struct FileCell: View {
        let entry: Entry

        init(_ entry: Entry) { self.entry = entry }

        var body: some View {
            Label {
                Text(entry.name).lineLimit(1).truncationMode(.middle)
            } icon: {
                Icon(entry.path.map(IconKind.file) ?? .symbol(Symbols.otherItems), size: .small)
            }
        }
    }

    /// A right-aligned size or count.
    struct NumberCell: View {
        let text: String

        init(bytes: Int64) { text = Format.bytes(bytes) }
        init(count: Int) { text = Format.count(count) }

        var body: some View {
            Text(text).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// A share of a whole, as a bar with the percentage.
    struct ShareCell: View {
        let fraction: Double

        init(_ part: Int64, of whole: Int64) { fraction = Double(part) / Double(max(whole, 1)) }

        var body: some View {
            HStack(spacing: Space.small) {
                ProgressView(value: Fraction.clamp(fraction)).progressViewStyle(.linear)
                Text(Format.percent(fraction)).monospacedDigit()
                    .frame(width: Layout.percentColumnWidth, alignment: .trailing)
            }
        }
    }
}
