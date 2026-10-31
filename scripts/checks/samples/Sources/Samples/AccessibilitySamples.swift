// swift-format-ignore-file
import SwiftUI

struct AccessibilitySamples: View {
    var body: some View {
        Image(nsImage: NSImage())  // expect: without an accessibility decision
    }
}
