// Optional picture comparison: photographs every page of the demo, light and dark, and compares
// the pictures with the ones you recorded before (see CONTRIBUTING.md).
//
// Start:  make snapshots, or make snapshots RECORD=1 to make the new pictures the references
// Needs:  Xcode 27 and screen recording for your terminal app (macOS asks the first time); only
//         you run it. Everything stays in snapshots/, which git ignores, because the pictures
//         depend on your screen and wallpaper.
import AppKit
import UniformTypeIdentifiers

// MARK: Settings

let appearances = ["light", "dark"]
let secondsUntilDrawn: UInt32 = 3
let microsecondsBetweenQuitChecks: UInt32 = 100_000
/// The same window size every time, whatever size the demo window had last, in AppKit's format
/// for a saved window: the window's x, y, width and height, then the same for the screen.
let windowFrame = "100 100 1100 860 0 0 2560 1440"
/// Layer 0 holds normal windows; menus and the menu bar sit above it.
let normalWindowLayer = 0
/// A pixel counts as changed when one color channel moves further than this (0–255); smaller
/// moves come from the glass picking up the wallpaper.
let channelTolerance = 24
/// A page counts as changed when more of its pixels changed than this share; the time in the
/// sidebar footer alone changes a few.
let changedShareAllowed = 0.01

/// Prints in the project's shared look through checks/console.py, with the Python make found
/// (PYTHON, together with PYTHONPATH); make starts this script in the project.
let python = ProcessInfo.processInfo.environment["PYTHON"] ?? ""

let folder = URL(filePath: "snapshots")
let referenceFolder = folder.appending(path: "reference")
let currentFolder = folder.appending(path: "current")
let differenceFolder = folder.appending(path: "difference")

// MARK: Pictures

/// One picture: a page in one appearance.
struct Picture {
    let page: String
    let appearance: String
    var fileName: String { "\(page)-\(appearance).png" }
}

/// Every page in every appearance; the app itself lists its pages, so this script keeps no copy.
func pictures(of app: URL) throws -> [Picture] {
    let listing = Process()
    let output = Pipe()
    listing.executableURL = app.appending(path: "Contents/MacOS/SpeicherExplorer")
    listing.arguments = ["--list-pages"]
    listing.standardOutput = output
    try listing.run()
    listing.waitUntilExit()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let pages = text.split(separator: "\n").map(String.init)
    return appearances.flatMap { appearance in
        pages.map { page in Picture(page: page, appearance: appearance) }
    }
}

// MARK: Printing

/// One piece of the shared look, such as show("passed", "home-light.png", "same").
func show(_ piece: String, _ texts: String...) {
    let drawing = Process()
    drawing.executableURL = URL(filePath: python)
    drawing.arguments = ["-m", "checks.console", piece] + texts
    // Without the console nothing can be reported, so the script stops and says why.
    guard (try? drawing.run()) != nil else {
        fatalError("no Python 3.13 or newer in PYTHON; install one, then run make snapshots")
    }
    drawing.waitUntilExit()
}

// MARK: Taking the pictures

func ensureScreenRecordingAccess() {
    guard !CGPreflightScreenCaptureAccess() else { return }
    CGRequestScreenCaptureAccess()
    show("failed", "Your terminal app may not record the screen yet")
    show("note", "Allow it in System Settings › Privacy & Security ›")
    show("note", "Screen & System Audio Recording, then run make snapshots again.")
    exit(EXIT_FAILURE)
}

func launch(_ app: URL, showing picture: Picture) async throws -> NSRunningApplication {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.arguments = [
        "-demo", "YES", "-pane", picture.page, "-appearance", picture.appearance,
        "-ApplePersistenceIgnoreState", "YES",  // do not reopen the windows of the last run
        "-NSWindow Frame main", windowFrame,  // the saved frame of the window named "main"
    ]
    return try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
}

/// The number of the app's main window; window numbers and owners need no permission.
func mainWindowNumber(of app: NSRunningApplication) -> Int? {
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
    let list = windows as? [[String: Any]] ?? []
    let ownWindow = list.first { window in
        window[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier
            && window[kCGWindowLayer as String] as? Int == normalWindowLayer
    }
    return ownWindow?[kCGWindowNumber as String] as? Int
}

func photograph(windowNumber: Int, to file: URL) throws {
    let capture = Process()
    capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
    // -x: no shutter sound, -o: without the window's shadow, -l: only the window with this number
    capture.arguments = ["-x", "-o", "-l\(windowNumber)", file.path]
    try capture.run()
    capture.waitUntilExit()
}

func quit(_ app: NSRunningApplication) {
    app.terminate()
    // `isTerminated` never changes in a script without a run loop, so ask the system instead:
    // the signal 0 sends nothing and only tells whether the process still exists.
    let processStillExists = { kill(app.processIdentifier, 0) == 0 }
    while processStillExists() { usleep(microsecondsBetweenQuitChecks) }
}

func take(_ pictures: [Picture], of app: URL) async throws {
    try? FileManager.default.removeItem(at: currentFolder)
    try FileManager.default.createDirectory(at: currentFolder, withIntermediateDirectories: true)
    for picture in pictures {
        let running = try await launch(app, showing: picture)
        sleep(secondsUntilDrawn)
        if let windowNumber = mainWindowNumber(of: running) {
            try photograph(
                windowNumber: windowNumber, to: currentFolder.appending(path: picture.fileName))
        } else {
            show("failed", picture.fileName, "no window found")
        }
        quit(running)
    }
}

// MARK: Comparing

/// The picture's pixels as RGBA bytes, drawn the same way for both pictures.
struct Pixels {
    static let bytesPerPixel = 4
    static let bitsPerChannel = 8
    static let colorChannels = 0..<3  // red, green and blue; the fourth byte is opacity
    static let opacity = 3
    static let fullChannel: UInt8 = 255

    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height * Self.bytesPerPixel)
    }

    init?(file: URL) {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        self.init(width: image.width, height: image.height)
        let area = CGRect(x: 0, y: 0, width: width, height: height)
        withContext { context in context.draw(image, in: area) }
    }

    /// Draws into or reads from `bytes` through a Core Graphics context.
    @discardableResult
    mutating func withContext<Result>(_ body: (CGContext) -> Result) -> Result? {
        let (width, height) = (self.width, self.height)
        return bytes.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: Self.bitsPerChannel,
                bytesPerRow: width * Self.bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            .map(body)
        }
    }

    func write(to file: URL) {
        var copy = self
        guard let image = copy.withContext({ context in context.makeImage() }) ?? nil,
            let destination = CGImageDestinationCreateWithURL(
                file as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}

/// The unchanged parts as a light gray copy (a quarter of the brightness on top of three quarters
/// white), so the red stands out.
let fadedShare = 4
let fadedBase = Int(Pixels.fullChannel) - Int(Pixels.fullChannel) / fadedShare
let changedColor: [UInt8] = [Pixels.fullChannel, 0, 0]  // red

/// The share of changed pixels, and a picture that shows them red over a faded original.
func compare(_ reference: Pixels, _ current: Pixels) -> (share: Double, difference: Pixels) {
    var difference = Pixels(width: current.width, height: current.height)
    var changed = 0
    for start in stride(from: 0, to: current.bytes.count, by: Pixels.bytesPerPixel) {
        let isChanged = Pixels.colorChannels.contains { channel in
            let index = start + channel
            return abs(Int(reference.bytes[index]) - Int(current.bytes[index])) > channelTolerance
        }
        if isChanged { changed += 1 }
        let faded = UInt8(Int(current.bytes[start]) / fadedShare + fadedBase)
        for channel in Pixels.colorChannels {
            difference.bytes[start + channel] = isChanged ? changedColor[channel] : faded
        }
        difference.bytes[start + Pixels.opacity] = Pixels.fullChannel
    }
    return (Double(changed) / Double(current.width * current.height), difference)
}

/// Prints one line per picture and returns whether all of them still match.
func compareWithReferences(_ pictures: [Picture]) -> Bool {
    try? FileManager.default.removeItem(at: differenceFolder)
    try? FileManager.default.createDirectory(
        at: differenceFolder, withIntermediateDirectories: true)
    var allMatch = true
    for picture in pictures {
        let verdict = verdict(for: picture.fileName)
        if verdict != nil { allMatch = false }
        show(verdict == nil ? "passed" : "failed", picture.fileName, verdict ?? "same")
    }
    return allMatch
}

/// What differs in one picture, or nil when it matches.
func verdict(for name: String) -> String? {
    guard let current = Pixels(file: currentFolder.appending(path: name)) else {
        return "no new picture"
    }
    guard let reference = Pixels(file: referenceFolder.appending(path: name)) else {
        return "no reference yet (make snapshots RECORD=1)"
    }
    guard reference.width == current.width, reference.height == current.height else {
        return "the window size changed (\(reference.width)×\(reference.height) → "
            + "\(current.width)×\(current.height))"
    }
    let (share, difference) = compare(reference, current)
    guard share > changedShareAllowed else { return nil }
    difference.write(to: differenceFolder.appending(path: name))
    let percent = share.formatted(.percent.precision(.fractionLength(1)))
    return "\(percent) changed, see snapshots/difference/\(name)"
}

func record() throws {
    try? FileManager.default.removeItem(at: referenceFolder)
    try FileManager.default.moveItem(at: currentFolder, to: referenceFolder)
    show("frame", "success", "The new pictures are now the references", "snapshots/reference")
}

// MARK: Run

let arguments = Array(CommandLine.arguments.dropFirst())
guard let appPath = arguments.first else {
    show("failed", "Which app?", "swift scripts/snapshots.swift <app> [--record]")
    exit(EXIT_FAILURE)
}
let app = URL(filePath: appPath)
let everyPicture = try pictures(of: app)
show("heading", "Speicher-Explorer · snapshots", "\(everyPicture.count) pictures")
ensureScreenRecordingAccess()
try await take(everyPicture, of: app)
if arguments.contains("--record") {
    try record()
} else {
    let allMatch = compareWithReferences(everyPicture)
    show(
        "frame", allMatch ? "success" : "failure",
        allMatch ? "Every picture matches its reference" : "Some pictures changed",
        allMatch ? "snapshots/reference" : "compare snapshots/current with snapshots/reference")
    exit(allMatch ? EXIT_SUCCESS : EXIT_FAILURE)
}
