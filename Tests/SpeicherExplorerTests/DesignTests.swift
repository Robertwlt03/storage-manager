import Foundation
import Testing

@testable import SpeicherExplorer

/// The design rules from CODE_STYLE.md that a value can break: grid, sizes, contrast, motion.
@Suite("Design")
struct DesignTests {
    private static let gridStep: CGFloat = 4
    private static let minimumContrast = 4.5
    private static let blackAndWhiteContrast = 21.0
    private static let sameColourContrast = 1.0
    private static let allowedRoundingError = 0.01

    @Test("Every spacing step sits on Apple's 4-point grid, except the hairline")
    func spacingFollowsTheGrid() {
        let steps = [Space.extraSmall, Space.small, Space.medium, Space.large, Space.extraLarge]
        for step in steps {
            #expect(step.truncatingRemainder(dividingBy: Self.gridStep) == 0, "\(step)")
        }
        #expect(Space.hairline < Space.extraSmall)
    }

    @Test("Spacing steps and icon sizes grow from small to large")
    func scalesGrow() {
        let steps = [
            Space.hairline, Space.extraSmall, Space.small, Space.medium, Space.large,
            Space.extraLarge,
        ]
        #expect(steps == steps.sorted())
        let iconSizes = [IconSize.extraSmall, .small, .medium, .large].map(\.rawValue)
        #expect(iconSizes == iconSizes.sorted())
    }

    @Test("The sidebar closes by itself exactly when sidebar and page no longer fit side by side")
    func sidebarCollapsesAtTheRightWidth() {
        #expect(Layout.sidebarCollapseWidth == Layout.sidebarIdealWidth + Layout.pageMinWidth)
        #expect(Layout.minWindowWidth <= Layout.sidebarCollapseWidth)
    }

    @Test("Quick animations are shorter than standard ones")
    func quickIsQuicker() {
        #expect(Motion.quickDuration > 0)
        #expect(Motion.quickDuration < Motion.standardDuration)
    }

    @Test("Every text colour reaches 4.5:1 in light and dark mode")
    func textContrast() {
        #expect(Checks.contrast())
    }

    @Test("The contrast formula gives the known WCAG values")
    func contrastFormula() {
        let blackOnWhite = Theme.contrastRatio(0xFFFFFF, 0x000000)
        #expect(abs(blackOnWhite - Self.blackAndWhiteContrast) < Self.allowedRoundingError)
        #expect(Theme.contrastRatio(0x777777, 0x777777) == Self.sameColourContrast)
        #expect(Theme.contrastRatio(0x000000, 0xFFFFFF) == blackOnWhite)
    }

    @Test("Category colours repeat instead of running out")
    func categoryColoursRepeat() {
        let count = Theme.categoryColors.count
        #expect(Theme.categoryColor(count) == Theme.categoryColor(0))
    }
}
