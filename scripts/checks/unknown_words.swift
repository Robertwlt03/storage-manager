// Asks the macOS spell checker which words are not American English.
//
// Start:  swift scripts/checks/unknown_words.swift [language] < words
//         (checks/language.py and checks/translations.py call it)
// Needs:  macOS; reads one word per line and prints one line per word the dictionary does not
//         know: the word, "british" or "unknown", and the checker's best guess, each separated by
//         a tab. Without a language it asks American English and tells British spellings apart;
//         with one, such as "de", it asks that language. A language macOS has no dictionary for
//         knows no word at all, so nothing slips through unchecked.
import AppKit

// MARK: Settings

let american = "en_US"
let british = "en_GB"
let separator = "\t"

/// How British endings turn American, tried in this order for a better guess than the checker's.
let americanEndings = [
    ("isation", "ization"), ("ising", "izing"), ("ises", "izes"), ("ised", "ized"), ("ise", "ize"),
    ("ysed", "yzed"), ("yse", "yze"),
    ("our", "or"), ("ours", "ors"), ("oured", "ored"), ("lled", "led"), ("tre", "ter"),
    ("ence", "ense"), ("lment", "llment"), ("ogue", "og"),
]

// MARK: Steps

/// Names such as Siri are only known capitalized, so both forms are asked.
func isKnown(_ word: String, in language: String) -> Bool {
    [word, word.capitalized]
        .contains { form in
            let misspelled = NSSpellChecker.shared.checkSpelling(
                of: form, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0,
                wordCount: nil)
            return misspelled.location == NSNotFound
        }
}

func americanSpelling(of word: String) -> String? {
    for (britishEnding, americanEnding) in americanEndings where word.hasSuffix(britishEnding) {
        let candidate = String(word.dropLast(britishEnding.count)) + americanEnding
        if isKnown(candidate, in: american) { return candidate }
    }
    return nil
}

func bestGuess(for word: String) -> String {
    let wholeWord = NSRange(location: 0, length: (word as NSString).length)
    let guesses = NSSpellChecker.shared.guesses(
        forWordRange: wholeWord, in: word, language: american, inSpellDocumentWithTag: 0)
    return guesses?.first ?? ""
}

func verdict(for word: String) -> String? {
    guard !isKnown(word, in: american) else { return nil }
    guard isKnown(word, in: british) else {
        return [word, "unknown", bestGuess(for: word)].joined(separator: separator)
    }
    let americanWord = americanSpelling(of: word) ?? bestGuess(for: word)
    return [word, "british", americanWord].joined(separator: separator)
}

func verdict(for word: String, in language: String) -> String? {
    let hasDictionary = NSSpellChecker.shared.availableLanguages.contains(language)
    guard !hasDictionary || !isKnown(word, in: language) else { return nil }
    return [word, "unknown", ""].joined(separator: separator)
}

// MARK: Run

let chosenLanguage = CommandLine.arguments.dropFirst().first
while let word = readLine() {
    let line = chosenLanguage.map { language in verdict(for: word, in: language) }
    if let line = line ?? verdict(for: word) { print(line) }
}
