import Foundation

/// The last scan as a plain-text report to keep or pass on: the summary, every category and the
/// largest files, each line readable without the app.
enum ReportService {
    static let listedFiles = 20

    struct Input {
        let date: Date
        let summary: String
        let categories: [Category]
        let largeFiles: [Entry]
    }

    static func text(_ input: Input) -> String {
        var lines = [
            TextKey.reportTitle.translated(with: Format.dateTime(input.date)), "", input.summary,
        ]
        lines += ["", TextKey.categories.translated]
        lines += input.categories.map { category in
            row(Format.bytes(category.bytes), category.kind.title.translated)
        }
        lines += ["", TextKey.paneLargeFiles.translated]
        lines += input.largeFiles.prefix(listedFiles)
            .map { file in
                row(Format.bytes(file.bytes), Paths.displayName(file.path ?? file.name))
            }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The size first and a tab after it, so the lines also paste into a spreadsheet.
    private static func row(_ size: String, _ name: String) -> String { size + "\t" + name }
}
