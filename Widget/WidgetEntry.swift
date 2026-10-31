import AppKit
import SwiftUI
import WidgetKit

/// Starts the widget extension; `--render-widget <file> [light|dark]` instead draws the widget
/// into a picture, so its look can be checked without adding it to the desktop.
@main
enum WidgetEntry {
    private static let renderCommand = "--render-widget"
    private static let darkAppearance = "dark"

    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: renderCommand), index + 1 < arguments.count {
            let isDark = arguments.dropFirst(index + 2).first == darkAppearance
            exit(
                WidgetPicture.render(to: arguments[index + 1], dark: isDark)
                    ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        StorageWidgets.main()
    }
}

struct StorageWidgets: WidgetBundle {
    var body: some Widget { FreeSpaceWidget() }
}

/// The small widget on a plain background, about the size macOS shows it.
private enum WidgetPicture {
    private static let side: CGFloat = 170
    private static let scale: CGFloat = 2

    static func render(to path: String, dark: Bool) -> Bool {
        let content = FreeSpaceView(entry: SpaceProvider.entry())
            .padding()
            .frame(width: side, height: side)
            .widgetPictureBackground()
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let image = renderer.cgImage,
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
