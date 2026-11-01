import Foundation
import Testing

@testable import StorageManager

/// The design rules from CODE_STYLE.md that a value can break: grid, sizes, contrast, motion.
@Suite("Design")
struct DesignTests {
    private static let gridStep: CGFloat = 4
    private static let minimumContrast = 4.5
    private static let blackAndWhiteContrast = 21.0
    private static let sameColorContrast = 1.0
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
        #expect(Layout.sidebarCollapseWidth == Layout.sidebarIdealWidth + Layout.pageMinimumWidth)
        #expect(Layout.minimumWindowWidth <= Layout.sidebarCollapseWidth)
    }

    @Test("Quick animations are shorter than standard ones")
    func quickIsQuicker() {
        #expect(Motion.quickDuration > 0)
        #expect(Motion.quickDuration < Motion.standardDuration)
    }

    /// Approximations of the system surfaces: content, window, cards and grouped rows, sidebar, and
    /// the glass of the toolbar.
    private static let lightSurfaces: [UInt32] = [0xFFFFFF, 0xF5F5F7, 0xECECEC, 0xE3E3E3, 0xDDE3EE]
    private static let darkSurfaces: [UInt32] = [
        0x1E1E1E, 0x262626, 0x2D2D2D, 0x323232, 0x3A3A3A, 0x28303E,
    ]
    private static let whiteText: UInt32 = 0xFFFFFF

    @Test("Every text color reaches 4.5:1 on every light and dark surface")
    func textContrast() {
        let textTones = [
            ("muted", Theme.muted), ("good", Theme.good), ("warning", Theme.warning),
            ("bad", Theme.bad),
        ]
        for (name, tone) in textTones {
            for surface in Self.lightSurfaces {
                let ratio = Contrast.ratio(tone.light, surface)
                #expect(ratio >= Self.minimumContrast, "\(name) light on \(surface): \(ratio)")
            }
            for surface in Self.darkSurfaces {
                let ratio = Contrast.ratio(tone.dark, surface)
                #expect(ratio >= Self.minimumContrast, "\(name) dark on \(surface): \(ratio)")
            }
        }
    }

    @Test("White button text reaches 4.5:1 on the primary button fill")
    func buttonContrast() {
        for color in [Theme.primaryFill.light, Theme.primaryFill.dark] {
            let ratio = Contrast.ratio(Self.whiteText, color)
            #expect(ratio >= Self.minimumContrast, "primary \(color): \(ratio)")
        }
    }

    @Test("The contrast formula gives the known WCAG values")
    func contrastFormula() {
        let blackOnWhite = Contrast.ratio(0xFFFFFF, 0x000000)
        #expect(abs(blackOnWhite - Self.blackAndWhiteContrast) < Self.allowedRoundingError)
        #expect(Contrast.ratio(0x777777, 0x777777) == Self.sameColorContrast)
        #expect(Contrast.ratio(0x000000, 0xFFFFFF) == blackOnWhite)
    }

    @Test("Every category has a color of its own, and the colors repeat instead of running out")
    func categoryColors() {
        let count = Theme.categoryColors.count
        #expect(count >= CategoryKind.allCases.count)
        #expect(Set(Theme.categoryColors).count == count)
        #expect(Theme.categoryColor(count) == Theme.categoryColor(0))
    }
}
