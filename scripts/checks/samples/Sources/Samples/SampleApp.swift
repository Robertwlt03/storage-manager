// swift-format-ignore-file
// Uses every sample, so only the planted mistakes count as dead code.
import SwiftUI

@main
enum SampleApp {
    static func main() {
        let initialCount = 2
        var statistics = Statistics(fileCount: initialCount, totalBytes: initialCount)
        statistics.fileCount += 1
        _ = (statistics.fileCount, TextKey.shown, Model().shownValue, BindingSample())
        _ = (RuleSamples(), ruleSamples(), probe(cfgValue: initialCount))
        _ = (deeplyNested(values: []), outerFunction(), Statistics.wrappedSignature(values: []))
        _ = (firstReport(entries: []), secondReport(entries: []))
        _ = (LayerSample().page, GadgetSample().page)
        _ = (removeQuietly, goOnline, AccessibilitySamples())
        _ = (DiskSamples.listFolder(""), QuietDiskSamples.listFolder(""))
        _ = (SecuritySamples.sharedCount, SecuritySamples.listThroughShell)
        _ = (SecuritySamples.scratchFile, SecuritySamples.separator)
    }
}
