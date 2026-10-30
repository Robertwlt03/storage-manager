// swift-format-ignore-file
import SwiftUI

struct RuleSamples: View {
    var body: some View {
        VStack {
            Text("Hello")  // expect: written-out text
            Menu("Options") {}  // expect: written-out text
            Image(systemName: "folder")  // expect: symbol name outside
            Color.red  // expect: outside Theme
        }
        .font(.title)  // expect: font set directly
        .glassEffect()  // expect: own glass
        .animation(.spring, value: 0)  // expect: animation outside
        .keyboardShortcut("s")
    }
}

func ruleSamples() {
    let go = 0  // expect: short name
    let doubled = [1].map { $0 }  // expect: instead of a named closure
    _ = doubled.count * 7  // expect: has no name
    _ = "Größe"  // expect: German text
    print(go)  // expect: output outside
    _ = "a line that runs on and on, well past the limit that swift format and the house rules allow"  // expect: longer than
    // expect below: temporary debug line
    _ = go // DBG
}
