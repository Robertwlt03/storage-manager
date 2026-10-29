// Optional picture comparison: photographs every page of the demo, light and dark, and compares
// the pictures with the ones you recorded before (see CONTRIBUTING.md). Start it with
// `make snapshots`, or `make snapshots RECORD=1` to make the new pictures the references.
// Only you run it: macOS asks once whether your terminal app may record the screen. Everything
// stays in snapshots/, which git ignores, because the pictures depend on your screen and wallpaper.
import AppKit
import UniformTypeIdentifiers

let pages = ["overview", "explorer", "largeFiles", "cleaner", "apps", "temp", "copies"]
let appearances = ["light", "dark"]
let secondsUntilDrawn: UInt32 = 3
/// A pixel counts as changed when one colour channel moves further than this (0–255); smaller
/// moves come from the glass picking up the wallpaper.
let channelTolerance = 24
/// A page counts as changed when more of its pixels changed than this share; the time in the
/// sidebar footer alone changes a few.
let changedShareAllowed = 0.01

let folder = URL(filePath: "snapshots")
let referenceFolder = folder.appending(path: "reference")
let currentFolder = folder.appending(path: "current")
let differenceFolder = folder.appending(path: "difference")

// MARK: Taking the pictures

func ensureScreenRecordingAccess() {
    guard !CGPreflightScreenCaptureAccess() else { return }
    CGRequestScreenCaptureAccess()
    print(
        """
        Your terminal app may not record the screen yet. Allow it in System Settings ›
        Privacy & Security › Screen & System Audio Recording, then run make snapshots again.
        """)
    exit(EXIT_FAILURE)
}

func launch(_ app: URL, page: String, appearance: String) async throws -> NSRunningApplication {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.arguments = [
        "-demo", "YES", "-pane", page, "-appearance", appearance,
        "-ApplePersistenceIgnoreState", "YES",
        // The same window size every time, whatever size the demo window had last.
        "-NSWindow Frame main", "100 100 1100 860 0 0 2560 1440",
    ]
    return try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
}

/// The number of the app's main window; window numbers and owners need no permission.
func mainWindowNumber(of app: NSRunningApplication) -> Int? {
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
    let list = windows as? [[String: Any]] ?? []
    let ownWindow = list.first { window in
        window[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier
            && window[kCGWindowLayer as String] as? Int == 0
    }
    return ownWindow?[kCGWindowNumber as String] as? Int
}

func photograph(windowNumber: Int, to file: URL) throws {
    let capture = Process()
    capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l\(windowNumber)", file.path]
    try capture.run()
    capture.waitUntilExit()
}

func quit(_ app: NSRunningApplication) {
    app.terminate()
    // `isTerminated` never changes in a script without a run loop, so ask the system instead.
    while kill(app.processIdentifier, 0) == 0 { usleep(100_000) }
}

func takePictures(of app: URL) async throws {
    try? FileManager.default.removeItem(at: currentFolder)
    try FileManager.default.createDirectory(at: currentFolder, withIntermediateDirectories: true)
    for appearance in appearances {
        for page in pages {
            let running = try await launch(app, page: page, appearance: appearance)
            sleep(secondsUntilDrawn)
            if let windowNumber = mainWindowNumber(of: running) {
                try photograph(
                    windowNumber: windowNumber,
                    to: currentFolder.appending(path: "\(page)-\(appearance).png"))
            } else {
                print("\(page)-\(appearance): no window found")
            }
            quit(running)
        }
    }
}

// MARK: Comparing

/// The picture's pixels as RGBA bytes, drawn the same way for both pictures.
struct Pixels {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
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
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
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

/// The share of changed pixels, and a picture that shows them red over a faded original.
func compare(_ reference: Pixels, _ current: Pixels) -> (share: Double, difference: Pixels) {
    var difference = Pixels(width: current.width, height: current.height)
    var changed = 0
    for start in stride(from: 0, to: current.bytes.count, by: 4) {
        let channels = start..<start + 3
        let isChanged = channels.contains { index in
            abs(Int(reference.bytes[index]) - Int(current.bytes[index])) > channelTolerance
        }
        if isChanged { changed += 1 }
        // The unchanged picture as a light grey copy, so the red stands out.
        let faded = UInt8(Int(current.bytes[start]) / 4 + 191)
        difference.bytes[start] = isChanged ? 255 : faded
        difference.bytes[start + 1] = isChanged ? 0 : faded
        difference.bytes[start + 2] = isChanged ? 0 : faded
        difference.bytes[start + 3] = 255
    }
    return (Double(changed) / Double(current.width * current.height), difference)
}

/// Prints one line per picture and returns whether all of them still match.
func compareWithReferences() -> Bool {
    try? FileManager.default.removeItem(at: differenceFolder)
    try? FileManager.default.createDirectory(
        at: differenceFolder, withIntermediateDirectories: true)
    var allMatch = true
    for appearance in appearances {
        for page in pages {
            let name = "\(page)-\(appearance).png"
            let verdict = verdict(for: name)
            if verdict != nil { allMatch = false }
            print("\(name): \(verdict ?? "same")")
        }
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
    return String(format: "%.1f %% changed, see snapshots/difference/%@", share * 100, name)
}

func record() throws {
    try? FileManager.default.removeItem(at: referenceFolder)
    try FileManager.default.moveItem(at: currentFolder, to: referenceFolder)
    print("The new pictures are now the references in snapshots/reference.")
}

// MARK: Run

let arguments = Array(CommandLine.arguments.dropFirst())
guard let appPath = arguments.first else {
    print("Usage: swift scripts/snapshots.swift <app> [--record]")
    exit(EXIT_FAILURE)
}
ensureScreenRecordingAccess()
try await takePictures(of: URL(filePath: appPath))
if arguments.contains("--record") {
    try record()
} else {
    exit(compareWithReferences() ? EXIT_SUCCESS : EXIT_FAILURE)
}
