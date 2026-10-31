import Foundation

/// The ways to free space that the overview suggests, in the order to take them.
enum FreeUpService {
    /// One way to free space and the page that does it; nil bytes are not known yet.
    struct Step: Identifiable, Equatable {
        let pane: Pane
        let bytes: Int64?
        var id: Pane { pane }
    }

    /// Less hardly changes how full the disk is, so such a step is not worth the user's time.
    static let smallestWorthwhileBytes: Int64 = 100_000_000

    /// Steps that free too little are left out; duplicates not searched yet stay, and so do
    /// unused apps whose size a partial scan did not measure (nil bytes for both).
    static func steps(cleanableBytes: Int64, duplicateBytes: Int64?, unusedApps: [AppUsage])
        -> [Step]
    {
        let appBytes = unusedApps.reduce(0) { total, app in total + app.bytes }
        let possibleSteps = [
            Step(pane: .cleaner, bytes: cleanableBytes),
            Step(pane: .duplicates, bytes: duplicateBytes),
            unusedApps.isEmpty ? nil : Step(pane: .apps, bytes: appBytes > 0 ? appBytes : nil),
        ]
        return possibleSteps.compactMap(\.self)
            .filter { step in step.bytes.map { bytes in bytes >= smallestWorthwhileBytes } ?? true }
    }

    /// What the steps with a known size free together.
    static func total(_ steps: [Step]) -> Int64 {
        steps.reduce(0) { total, step in total + (step.bytes ?? 0) }
    }
}
