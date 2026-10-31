import SwiftUI

/// The subfolders of a folder as rings around its name: the bigger a folder, the wider its piece.
/// A click opens the folder; the middle names the piece under the mouse.
struct SunburstChart: View {
    let folder: Node
    @Environment(AppModel.self) private var model
    @State private var hovered: Node?
    /// Laid out once per tree revision, not on every mouse move.
    @State private var segments: [SunburstSegment] = []

    /// Outer rings fade, so the inner ones read first.
    private static let ringOpacities = [1.0, 0.75, 0.5]
    private static let gapShare = 0.004
    private static let nameLines = 2
    private static let half = 0.5
    private static let quarterTurn = 0.25
    private static let circleDegrees = 360.0

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            ZStack {
                ForEach(segments, content: piece)
                centerLabel.frame(width: diameter * SunburstService.holeShare)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(.rect)
            // One hit test for all pieces: a shape's own hover area would be its whole frame.
            .onContinuousHover { phase in
                hovered = hoveredNode(phase, in: geometry.size, of: segments)
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { tap in
                        segment(at: tap.location, in: geometry.size, of: segments)
                            .map { segment in model.open(segment.node) }
                    })
        }
        .padding(Space.page)
        .task(id: model.revision) { segments = SunburstService.segments(of: folder) }
    }

    private func piece(_ segment: SunburstSegment) -> some View {
        let inner = SunburstService.innerRadius(ofRing: segment.ring)
        return RingPiece(
            start: segment.start, end: segment.end, inner: inner,
            outer: inner + SunburstService.ringWidth, gap: Self.gapShare
        )
        .fill(Theme.categoryColor(segment.branch))
        .opacity(Self.ringOpacities[segment.ring])
        .accessibilityElement()
        .accessibilityLabel(segment.node.displayName)
        .accessibilityValue(Format.bytes(segment.node.bytes))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.open(segment.node) }
    }

    private func hoveredNode(_ phase: HoverPhase, in size: CGSize, of segments: [SunburstSegment])
        -> Node?
    {
        guard case .active(let location) = phase else { return nil }
        return segment(at: location, in: size, of: segments)?.node
    }

    /// Turns a point into a distance and an angle from the middle and looks up the piece there.
    private func segment(at point: CGPoint, in size: CGSize, of segments: [SunburstSegment])
        -> SunburstSegment?
    {
        let radius = min(size.width, size.height) * Self.half
        let offsetX = point.x - size.width * Self.half
        let offsetY = point.y - size.height * Self.half
        let fullTurn = Angle.degrees(Self.circleDegrees).radians
        let turn = (atan2(offsetY, offsetX) / fullTurn + Self.quarterTurn + 1)
            .truncatingRemainder(dividingBy: 1)
        return SunburstService.segment(
            atRadius: hypot(offsetX, offsetY) / radius, turn: turn, in: segments)
    }

    private var centerLabel: some View {
        let shown = hovered ?? folder
        return VStack(spacing: Space.extraSmall) {
            Text(shown.isVirtual ? TextKey.paneExplorer.translated : shown.displayName)
                .textRole(.section).lineLimit(Self.nameLines)
            Text(Format.bytes(shown.bytes)).textRole(.caption)
        }
        .multilineTextAlignment(.center)
        .accessibilityHidden(true)  // every piece names itself
    }
}

/// A piece of a ring between two shares of the circle, starting at the top and going clockwise.
private nonisolated struct RingPiece: Shape {
    let start, end, inner, outer, gap: Double

    private static let circleDegrees = 360.0
    private static let topDegrees = -90.0
    private static let half = 0.5

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * Self.half
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfGap = gap * Self.half
        let startAngle = angle(start + halfGap)
        let endAngle = angle(max(end - halfGap, start + halfGap))
        var path = Path()
        path.addArc(
            center: center, radius: radius * outer, startAngle: startAngle, endAngle: endAngle,
            clockwise: false)
        path.addArc(
            center: center, radius: radius * inner, startAngle: endAngle, endAngle: startAngle,
            clockwise: true)
        path.closeSubpath()
        return path
    }

    private func angle(_ share: Double) -> Angle {
        .degrees(Self.topDegrees + Self.circleDegrees * share)
    }
}
