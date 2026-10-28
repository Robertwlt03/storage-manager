import AppKit
import SwiftUI

// MARK: Pixel icons (same grids as the terminal prototype: letter = colour, dot = empty)

enum Art {
    static let palette: [Character: Color] = [
        "R": Color(hex: 0xFF0000), "G": Color(hex: 0x00AF00), "Y": Color(hex: 0xFFD700), "B": Color(hex: 0x0087FF),
        "W": Color(hex: 0xEEEEEE), "D": Color(hex: 0x585858), "L": Color(hex: 0xBCBCBC), "K": Color(hex: 0x303030),
        "A": Color(hex: 0xD78700), "O": Color(hex: 0xFFAF00), "S": Color(hex: 0xFFD7AF), "M": Color(hex: 0xD75FD7),
        "C": Color(hex: 0x00AFAF), "T": Color(hex: 0xFF5F5F), "N": Color(hex: 0x5FD7FF),
    ]

    static let chrome = ["....RRRRR....", "..RRRRRRRRR..", ".RRRRRRRRRRR.", ".GRRRWWWRRRR.", "GGGRWBBBWRYYY", "GGGWBBBBBWYYY",
                         "GGGWBBBBBWYYY", "GGGWBBBBBWYYY", "GGGGWBBBWYYYY", ".GGGGWWWYYYY.", ".GGGGGGYYYYY.", "..GGGGGYYYY..",
                         "....GGGYY....", "............."]
    static let drive = [".............", ".LLLLLLLLLLL.", "LDDDDDDDDDDDL", "LDKKKKKKKKKDL", "LDKKKKKKKKKDL", "LDDDDDDDDDDDL",
                        "LDDDDDDDDCDGL", "LDDDDDDDDDDDL", ".LLLLLLLLLLL.", "............."]
    static let hourglass = ["AAAAAAAAAAAAA", ".A.........A.", "..A.SSSSS.A..", "...A.SSS.A...", "....A.S.A....", ".....A.A.....",
                            "....A.O.A....", "...A.OOO.A...", "..A.OOOOO.A..", ".A.OOOOOOO.A.", "AAAAAAAAAAAAA", "............."]
    static let folder = [".............", ".AAAAA.......", "AAAAAAAAAAAAA", "AYYYYYYYYYYYA", "AYYYYYYYYYYYA", "AYYYYYYYYYYYA",
                         "AYYYYYYYYYYYA", "AAAAAAAAAAAAA", ".............", "............."]
    static let magnifier = ["...LLLLL.....", "..L.....L....", ".L..NNN..L...", ".L.NNNNN.L...", ".L..NNN..L...", "..L.....L....",
                            "...LLLLLD....", "........DD...", ".........DD..", "..........DD.", "...........DD", "............."]
    static let docker = ["......NN.....", "...NN.NN.....", "NN.NN.NN.NN..", "BBBBBBBBBBBB.", "BBBBBBBBBBWB.", ".BBBBBBBBBBB.",
                         "..BBBBBBBB...", "............."]
    static let claude = ["......T......", "...T..T..T...", "....T.T.T....", ".....TTT.....", "TTTTTTTTTTTTT", ".....TTT.....",
                         "....T.T.T....", "...T..T..T...", "......T......", "............."]
    static let trash = [".....LLL.....", "LLLLLLLLLLLLL", ".DDDDDDDDDDD.", ".DLDDLDDLDDD.", ".DLDDLDDLDDD.", ".DLDDLDDLDDD.",
                        ".DLDDLDDLDDD.", "..DDDDDDDDD..", ".............", "............."]

    /// Ring of `fraction` used (magenta) and the rest free (cyan).
    static func donut(_ fraction: Double) -> [String] {
        (0..<14).map { y in
            String((0..<13).map { x -> Character in
                let dx = Double(x) - 6, dy = Double(y) - 6.5, d = (dx * dx + dy * dy).squareRoot()
                if d > 6.6 || d < 3.2 { return "." }
                var a = atan2(dx, -dy)
                if a < 0 { a += 2 * .pi }
                return a <= fraction * 2 * .pi ? "M" : "C"
            })
        }
    }

    static func forPath(_ url: URL) -> [String] {
        let p = url.path
        if p.localizedCaseInsensitiveContains("chrome") { return chrome }
        if p.localizedCaseInsensitiveContains("docker") { return docker }
        if p.localizedCaseInsensitiveContains("claude") { return claude }
        if p.contains(".Trash") { return trash }
        if p.hasPrefix(Disk.tempArea.path) { return hourglass }
        return folder
    }
}

struct PixelIcon: View {
    let rows: [String]
    var pixel: CGFloat = 5

    var body: some View {
        let w = CGFloat(rows.first?.count ?? 0), h = CGFloat(rows.count), side = max(w, h) * pixel
        Canvas { ctx, _ in
            let dx = (side - w * pixel) / 2, dy = (side - h * pixel) / 2
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let c = Art.palette[ch] else { continue }
                    ctx.fill(Path(CGRect(x: dx + CGFloat(x) * pixel, y: dy + CGFloat(y) * pixel, width: pixel, height: pixel)), with: .color(c))
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// Pixel icon on a dark tile, so light-grey pixels stay visible in light mode.
struct PixelTile: View {
    let rows: [String]
    var pixel: CGFloat = 5

    var body: some View {
        PixelIcon(rows: rows, pixel: pixel)
            .padding(pixel * 2)
            .background(.tile, in: RoundedRectangle(cornerRadius: pixel * 3.5, style: .continuous))
    }
}

/// App icon for build.sh (1024 px canvas, 824 px tile as in Apple's icon grid).
struct AppIconView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 185, style: .continuous)
            .fill(Color(hex: 0x1C1C20))
            .frame(width: 824, height: 824)
            .overlay(PixelIcon(rows: Art.donut(0.62), pixel: 46))
            .frame(width: 1024, height: 1024)
    }
}

// MARK: Layout

struct Screen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(28)
                .frame(maxWidth: 1000, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.fg)
        .background(.bg)
    }
}

struct Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.headline).padding(.bottom, 4) }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Icon on the left, title, subtitle and extra lines on the right.
struct Header<Extra: View>: View {
    let art: [String]
    let title: String
    let subtitle: String
    @ViewBuilder var extra: Extra

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            PixelTile(rows: art, pixel: 5)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.largeTitle.bold()).foregroundStyle(.accentText)
                Text(subtitle).foregroundStyle(.muted).textSelection(.enabled).lineLimit(2)
                extra.padding(.top, 4)
            }
        }
    }
}

struct Loading: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.muted)
        }
    }
}

// MARK: Sizes

struct SizeBar: View {
    let value: Int64
    let total: Int64
    var fill: Color? = nil

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.track)
                Capsule().fill(fill ?? Self.color(value))
                    .frame(width: total > 0 && value > 0 ? max(6, g.size.width * CGFloat(value) / CGFloat(total)) : 0)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    /// Green under 1 GB, then yellow, orange from 5 GB, red from 20 GB (like the prototype).
    static func color(_ bytes: Int64) -> Color {
        let gb = Double(bytes) / 1_073_741_824
        return gb >= 20 ? Color(hex: 0xE5383B) : gb >= 5 ? Color(hex: 0xF07F1A) : gb >= 1 ? Color(hex: 0xE0B000) : Color(hex: 0x2FA84F)
    }
}

struct SizeRow: View {
    let bytes: Int64?
    let total: Int64
    let label: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            SizeBar(value: bytes ?? 0, total: total).frame(width: 140)
            Text(bytes.map(Disk.bytes) ?? "…").bold().monospacedDigit().frame(width: 80, alignment: .trailing)
            if let symbol { Image(systemName: symbol).foregroundStyle(.muted).frame(width: 18) }
            Text(label).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

/// A list row that highlights on hover.
struct RowButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(hover ? Color.track : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct DiskLine: View {
    var body: some View {
        let v = Disk.volume()
        HStack(spacing: 10) {
            SizeBar(value: v.used, total: v.total, fill: .usedRing).frame(width: 180)
            Text("\(Text(Disk.bytes(v.used)).bold()) belegt von \(Disk.bytes(v.total)) · \(Text("\(Disk.bytes(v.free)) frei").bold().foregroundStyle(.freeText))")
        }
    }
}

func revealInFinder(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
