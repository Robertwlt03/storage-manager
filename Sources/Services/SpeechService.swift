import AVFoundation
import Observation

/// Reads a text aloud with the system voice of the app's language.
@MainActor @Observable final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String) {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: Localizer.shared.locale)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// A Siri voice of the app's language if macOS offers one, otherwise the best installed voice, otherwise the default.
    /// More voices, including other Siri voices, can be added in System Settings › Accessibility › Spoken Content.
    static func bestVoice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        let code = locale.language.languageCode?.identifier ?? AppLanguage.fallback.rawValue
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(code) }
        return voices.first { $0.identifier.localizedCaseInsensitiveContains(siriMarker) }
            ?? voices.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: locale.identifier)
    }

    private static let siriMarker = "siri"

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { done() }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { done() }

    private nonisolated func done() { Task { @MainActor in SpeechService.shared.isSpeaking = false } }
}
