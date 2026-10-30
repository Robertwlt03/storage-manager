import Foundation

/// The shared look of everything the app prints in a terminal (the self test, the stress test and
/// the list of pages), the same pieces as scripts/console.sh and scripts/checks/console.py: a
/// heading, lines with a mark (✔ done, ✘ failed, › under way) and dimmed details, dimmed hints
/// and a frame that sums up. Colors appear in a terminal; NO_COLOR turns them off and FORCE_COLOR
/// turns them on (see no-color.org), as for `make selftest`, which writes into a file.
enum Console {
    /// Terminal codes for text styles (ECMA-48 "select graphic rendition").
    private enum Style: String {
        case bold = "1"
        case dim = "2"
        case failure = "31"  // red
        case success = "32"  // green
        case step = "36"  // cyan
    }

    private static let passedMark = "✔"
    private static let failedMark = "✘"
    private static let stepMark = "›"
    private static let noteIndent = "   "
    /// Set once a heading shows, the same name as in console.sh and console.py.
    private static let headedVariable = "CONSOLE_HEADED"
    /// Space inside a frame, one character on each side of the longest line.
    private static let framePadding = 2

    private static let usesColor: Bool = {
        let environment = ProcessInfo.processInfo.environment
        let isTerminal = isatty(STDOUT_FILENO) != 0
        return environment["NO_COLOR"] == nil
            && (isTerminal || environment["FORCE_COLOR"] != nil)
    }()

    // MARK: What the app prints

    /// Opens a command, once only: what the command starts afterwards leaves out its own heading.
    static func heading(_ title: String, detail: String = "") {
        guard ProcessInfo.processInfo.environment[headedVariable] == nil else { return }
        setenv(headedVariable, "1", 1)
        show("\n\(paint(title, .bold))  \(paint(detail, .dim))\n")
    }

    static func passed(_ text: String, detail: String = "") {
        show(resultLine(paint(passedMark, .success, .bold), text, detail))
    }

    static func failed(_ text: String, detail: String = "") {
        show(resultLine(paint(failedMark, .failure, .bold), text, detail))
    }

    static func step(_ text: String, detail: String = "") {
        show(resultLine(paint(stepMark, .step, .bold), text, detail))
    }

    static func note(_ text: String) {
        show(paint(noteIndent + text, .dim))
    }

    /// Ends a command, the same shape everywhere: the outcome after its mark, green when it passed
    /// and red when it failed, then below it what it concerns.
    static func frame(_ outcome: String, details: [String] = [], passed: Bool) {
        let color: Style = passed ? .success : .failure
        let title = "\(passed ? passedMark : failedMark) \(outcome)"
        let indented = details.map { detail in "  \(detail)" }
        let lines = [(title, paint(title, color, .bold))] + indented.map { line in (line, line) }
        let width = (lines.map(\.0.count).max() ?? 0) + framePadding
        let border = String(repeating: "─", count: width)
        let side = paint("│", color)
        let rows = lines.map { plain, shown in
            let padding = String(repeating: " ", count: width - plain.count - 1)
            return " \(side) \(shown)\(padding)\(side)"
        }
        let top = " " + paint("╭\(border)╮", color)
        let bottom = " " + paint("╰\(border)╯", color)
        show((["", top] + rows + [bottom, ""]).joined(separator: "\n"))
    }

    /// Plain text another program reads; never colored.
    static func data(_ text: String) {
        print(text)
    }

    // MARK: Pieces

    private static func resultLine(_ mark: String, _ text: String, _ detail: String) -> String {
        " \(mark) \(text)" + (detail.isEmpty ? "" : "  " + paint(detail, .dim))
    }

    private static func paint(_ text: String, _ styles: Style...) -> String {
        guard usesColor, !styles.isEmpty else { return text }
        let codes = styles.map(\.rawValue).joined(separator: ";")
        return "\u{1B}[\(codes)m\(text)\u{1B}[0m"
    }

    /// Every piece ends here, at once, so the lines keep their order beside other output.
    private static func show(_ text: String) {
        print(text)
        fflush(stdout)
    }
}
