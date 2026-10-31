import Testing

@testable import StorageManager

/// The steps the overview offers to free space.
@Suite("Free up")
struct FreeUpTests {
    @Test(
        "The overview's steps come in order, without what frees too little, adding up what is known"
    )
    func freeUpSteps() {
        let worthwhile = FreeUpService.smallestWorthwhileBytes
        let app = AppUsage(
            path: "/a.app", name: "a", bundleID: nil, lastUsed: nil, bytes: worthwhile)
        let unmeasuredApp = AppUsage(path: "/b.app", name: "b", bundleID: nil, lastUsed: nil)
        let everyStep = FreeUpService.steps(
            cleanableBytes: worthwhile, duplicateBytes: worthwhile * 2,
            unusedApps: [app, unmeasuredApp])
        #expect(everyStep.map(\.pane) == [.cleaner, .duplicates, .apps])
        #expect(FreeUpService.total(everyStep) == worthwhile * 4)
        let unknownOnly = FreeUpService.steps(
            cleanableBytes: worthwhile - 1, duplicateBytes: nil, unusedApps: [unmeasuredApp])
        #expect(
            unknownOnly == [.init(pane: .duplicates, bytes: nil), .init(pane: .apps, bytes: nil)])
        #expect(FreeUpService.total(unknownOnly) == 0)
        #expect(FreeUpService.steps(cleanableBytes: 1, duplicateBytes: 0, unusedApps: []).isEmpty)
    }
}
