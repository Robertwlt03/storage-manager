// swift-format-ignore-file
import Foundation

enum SecuritySamples {
    // Only the samples read it, from one thread: a reason, so the check stays quiet.
    nonisolated(unsafe) static var explainedCount = 1
    static let copiedCount = explainedCount
    // The note is a block comment on purpose: the check takes only line comments for a reason.
    static let separator = copiedCount
    nonisolated(unsafe) static var sharedCount = 0  /* expect: switches off Swift's safety */

    static func listThroughShell(_ folder: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")  // expect: starts a shell
        process.arguments = ["-c", "ls " + folder]
        try process.run()
    }

    static let scratchFile = URL(fileURLWithPath: "/tmp/samples.txt")  // expect: shared temporary
}
