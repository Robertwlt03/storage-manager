// swift-format-ignore-file
import SwiftUI

struct Statistics {
    var fileCount = 0
    var totalBytes = 0  // expect: assigned but never read
}

func neverCalled() {}  // expect: declared but never used

enum TextKey: String, CaseIterable {
    case shown
    case neverShown  // expect: never shown
}

@Observable
final class Model {
    var shownValue = 0
    var unusedValue = 0  // expect: declared but never used
}

/// A property used only through its binding counts as used.
struct BindingSample: View {
    @State private var isOn = false
    var body: some View { Toggle(TextKey.shown.rawValue, isOn: $isOn) }
}
