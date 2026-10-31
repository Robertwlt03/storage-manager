import AVFoundation
import Observation

/// Reads a text aloud with the system voice of the app's language. As a speech delegate it counts
/// as Sendable, which the main-actor default does not cover, so it says `@MainActor` itself.
@MainActor @Observable final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()
    private static let siriMarker = "siri"

    private(set) var isSpeaking = false
    /// False when macOS has no voice for the app's language; then nothing is
    /// offered for reading aloud, as another language's voice would garble the text.
    let canSpeak = bestVoice(for: Localizer.shared.locale) != nil
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

    /// A Siri voice of the app's language if macOS offers one, otherwise the best installed voice,
    /// otherwise the default. More voices, including other Siri voices, can be added in System
    /// Settings › Accessibility › Spoken Content.
    private static func bestVoice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        let languageCode = locale.language.languageCode?.identifier ?? AppLanguage.fallback.rawValue
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in voice.language.hasPrefix(languageCode) }
        let siriVoice = voices.first { voice in
            voice.identifier.localizedCaseInsensitiveContains(siriMarker)
        }
        return siriVoice
            ?? voices.max { left, right in left.quality.rawValue < right.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: locale.identifier)
    }

    nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance
    ) {
        markAsFinished()
    }
    nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance
    ) {
        markAsFinished()
    }

    private nonisolated func markAsFinished() {
        Task { @MainActor in SpeechService.shared.isSpeaking = false }
    }
}
