import SwiftUI

/// App icon for build.sh: 1024 px canvas, 824 px rounded square as in Apple's macOS icon grid.
struct AppIconView: View {
    private static let canvas: CGFloat = 1024
    private static let tile: CGFloat = 824
    private static let corner: CGFloat = 185
    private static let ring: CGFloat = 440
    private static let lineWidth: CGFloat = 96
    private static let top = Color(red: 0.36, green: 0.62, blue: 1.0)
    private static let bottom = Color(red: 0.12, green: 0.32, blue: 0.86)
    /// Ring segments as (from, to, opacity).
    private static let segments: [(Double, Double, Double)] = [(0, 0.46, 1), (0.47, 0.70, 0.78), (0.71, 0.84, 0.55)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.tile, height: Self.tile)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: Self.lineWidth)
                ForEach(Self.segments.indices, id: \.self) { i in
                    let (from, to, opacity) = Self.segments[i]
                    Circle().trim(from: from, to: to)
                        .stroke(.white.opacity(opacity), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: Self.ring, height: Self.ring)
        }
        .frame(width: Self.canvas, height: Self.canvas)
    }
}
