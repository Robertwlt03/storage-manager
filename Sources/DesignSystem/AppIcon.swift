import SwiftUI

/// App icon for build.sh: 1024 px canvas, 824 px rounded square as in Apple's macOS icon grid.
struct AppIconView: View {
    /// A piece of the ring, from where it starts to where it ends as a share of the full circle.
    private struct RingSegment {
        let start: Double
        let end: Double
        let opacity: Double
    }

    private static let canvasSize: CGFloat = 1024
    private static let tileSize: CGFloat = 824
    private static let cornerRadius: CGFloat = 185
    private static let ringSize: CGFloat = 440
    private static let lineWidth: CGFloat = 96
    private static let shadowRadius: CGFloat = 18
    private static let shadowDrop: CGFloat = 10
    private static let twelveOClock = Angle.degrees(-90)
    private static let largestSegment = RingSegment(start: 0, end: 0.46, opacity: 1)
    private static let middleSegment = RingSegment(start: 0.47, end: 0.70, opacity: 0.78)
    private static let smallestSegment = RingSegment(start: 0.71, end: 0.84, opacity: 0.55)
    private static let segments = [largestSegment, middleSegment, smallestSegment]

    var body: some View {
        ZStack {
            tile
            ring.frame(width: Self.ringSize, height: Self.ringSize)
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
    }

    private var tile: some View {
        let gradient = LinearGradient(
            colors: [Theme.appIconTop, Theme.appIconBottom], startPoint: .top, endPoint: .bottom)
        return RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(gradient)
            .frame(width: Self.tileSize, height: Self.tileSize)
            .shadow(color: Theme.appIconShadow, radius: Self.shadowRadius, y: Self.shadowDrop)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.appIconRingTrack, lineWidth: Self.lineWidth)
            ForEach(Self.segments, id: \.start) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        Theme.appIconRing.opacity(segment.opacity),
                        style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(Self.twelveOClock)
            }
        }
    }
}
