import Foundation

/// The widget's texts, from Widget.strings in each language folder of its bundle. The widget
/// follows the Mac's language, because it cannot read the language chosen in the app.
nonisolated enum WidgetText: String {
    case widgetName, widgetDescription, widgetAvailable, widgetOfTotal, widgetUnreadable

    private static let table = "Widget"

    var translated: String {
        Bundle.main.localizedString(forKey: rawValue, value: nil, table: Self.table)
    }

    func translated(with value: String) -> String { String(format: translated, value) }
}
