import Foundation

/// One folder as a piece of a ring: its ring counted from the inside, and where it starts and ends
/// as a share of the full circle.
nonisolated struct SunburstSegment: Identifiable {
    let node: Node
    let ring: Int
    let start: Double
    let end: Double
    /// The top folder it lies in, so a branch keeps one color outwards.
    let branch: Int
    var id: String { node.path }
}

/// Lays out the subfolders of a folder as rings: each folder takes the share of its parent's piece
/// that its size takes of the parent. Files leave a gap, so the gaps show what lies loose inside.
nonisolated enum SunburstService {
    static let rings = 3
    /// Thinner pieces could not be seen or clicked.
    static let smallestShare = 0.004
    /// The empty middle, as a share of the radius; the rings share the rest equally.
    static let holeShare = 0.3
    static let ringWidth = (1 - holeShare) / Double(rings)

    static func innerRadius(ofRing ring: Int) -> Double { holeShare + ringWidth * Double(ring) }

    /// The piece at a point given by its distance from the middle (a share of the radius) and its
    /// angle (a share of the full turn, clockwise from the top).
    static func segment(atRadius radius: Double, turn: Double, in segments: [SunburstSegment])
        -> SunburstSegment?
    {
        guard radius >= holeShare else { return nil }
        let ring = Int((radius - holeShare) / ringWidth)
        return segments.first { segment in
            segment.ring == ring && segment.start <= turn && turn < segment.end
        }
    }

    static func segments(of folder: Node) -> [SunburstSegment] {
        var segments: [SunburstSegment] = []
        addChildren(of: folder, within: 0...1, ring: 0, branch: nil, into: &segments)
        return segments
    }

    private static func addChildren(
        of folder: Node, within span: ClosedRange<Double>, ring: Int, branch: Int?,
        into segments: inout [SunburstSegment]
    ) {
        guard ring < rings, folder.bytes > 0 else { return }
        let sharePerByte = (span.upperBound - span.lowerBound) / Double(folder.bytes)
        var childStart = span.lowerBound
        for (index, child) in folder.children.enumerated() {
            let childEnd = childStart + Double(child.bytes) * sharePerByte
            if childEnd - childStart >= smallestShare {
                let childBranch = branch ?? index
                segments.append(
                    SunburstSegment(
                        node: child, ring: ring, start: childStart, end: childEnd,
                        branch: childBranch))
                addChildren(
                    of: child, within: childStart...childEnd, ring: ring + 1,
                    branch: childBranch, into: &segments)
            }
            childStart = childEnd
        }
    }
}
