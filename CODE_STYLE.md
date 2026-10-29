<p align="center">
  <img src="assets/banner-code-regeln.svg" alt="Code-Regeln des Speicher-Explorers. So schreiben wir Code, den jeder lesen kann." width="100%">
</p>

Code wird viel öfter gelesen als geschrieben. Deshalb soll sich der Code des Speicher-Explorers fast wie ein Text
lesen lassen, auch für Menschen, die nicht jeden Winkel von Swift kennen. Diese Regeln gelten für jede Zeile, und das
Prüfskript am Ende dieser Seite kontrolliert die meisten davon automatisch.

## <img src="assets/icons/format.svg" height="33" align="absmiddle" alt="">Kurze Zeilen und einheitliche Form

Keine Zeile ist länger als 100 Zeichen, und eingerückt wird mit vier Leerzeichen. Die Form legt nicht jeder selbst
fest, sondern das Werkzeug `swift format` mit der Einstellungsdatei `.swift-format`. Es bricht lange Aufrufe um und
setzt jeden Schritt einer langen Kette in eine eigene Zeile. Wie viele Zeilen dadurch entstehen, ist egal, denn eine
kurze Zeile liest man schneller als eine lange.

```bash
make format
```

## <img src="assets/icons/names.svg" height="33" align="absmiddle" alt="">Namen in Alltagssprache

Namen sind auf Englisch und ausgeschrieben. Wir wählen Wörter, die man aus dem Alltag kennt, und keine Abkürzungen,
denn `category` versteht jeder, `cat` dagegen klingt nach einer Katze. Ein Name sagt, was etwas ist oder tut:

- **Werte** heißen nach ihrem Inhalt, zum Beispiel `largeFiles` statt `list` oder `result`.
- **Funktionen** beginnen mit einem Verb, zum Beispiel `scan()`, `openSettings()` oder `refreshStatistics()`.
- **Wahrheitswerte** lesen sich wie eine Frage, zum Beispiel `isEmpty`, `hasFullDiskAccess` oder `canSelect`.
- **Parameter in Closures** bekommen ebenfalls einen Namen. Wir schreiben `{ file in file.bytes }` und nicht
  `{ $0.bytes }`, damit man nicht raten muss, was `$0` ist.

Namen aus ein oder zwei Buchstaben gibt es nicht. Erlaubt sind nur `id` sowie `x` und `y` für Koordinaten, weil diese
Wörter jeder kennt.

## <img src="assets/icons/numbers.svg" height="33" align="absmiddle" alt="">Keine Zahlen ohne Namen

Eine Zahl mitten im Code verrät nicht, was sie bedeutet. Deshalb bekommt jede Zahl einen Namen, und der Code liest
sich dann wie ein Satz: `.padding(Space.card)` statt `.padding(16)`. Nur `0` und `1` dürfen ohne Namen stehen, wenn
sie einfach zählen, also für „nichts“ oder „eins weiter“. Bedeuten sie etwas Bestimmtes, etwa volle Deckkraft oder eine
abgeschlossene Messung, bekommen auch sie einen Namen.

Jeder Name hat einen festen Ort:

| Wofür | Wo |
| --- | --- |
| Abstände, Icon-Größen, Maße und Symbolnamen | `Sources/DesignSystem/Tokens.swift` |
| Farben | `Sources/DesignSystem/Theme.swift` |
| Dauer und Art von Animationen | `Sources/DesignSystem/Motion.swift` |
| Grenzen der Messung, des Aufräumens und der Suche | `Sources/Core/Constants.swift` |
| Werte, die nur ein einziger Typ braucht | als `private static let` direkt in diesem Typ |

## <img src="assets/icons/palette.svg" height="33" align="absmiddle" alt="">Farben an einem Ort

Jede Farbe der App kommt aus `Theme.swift`. Dort ist sie einmal für das helle und einmal für das dunkle Erscheinungsbild
festgelegt und erreicht in beiden einen Kontrast von mindestens 4,5 zu 1. Alle anderen Dateien verwenden nur diese
Namen und legen nie selbst eine Farbe an, auch kein `.white` oder `Color(red:green:blue:)`. Wer eine neue Farbe braucht,
ergänzt sie in `Theme.swift` und in der Liste der Kontrast-Tests in `DesignTests.swift`.

## <img src="assets/icons/design.svg" height="33" align="absmiddle" alt="">Gestaltung aus einem Guss

Damit gleiche Dinge überall gleich aussehen, hat jede Gestaltungsentscheidung genau einen Ort, und die Seiten
benutzen nur deren Namen:

- **Schriften** kommen über `.textRole(...)` aus `TextRole`, zum Beispiel `.textRole(.hint)`, und nie direkt über
  `.font(...)`.
- **Symbole** stehen mit ihrem Namen in `Symbols` in `Tokens.swift`, zum Beispiel `Symbols.trash`, und nie als
  Zeichenkette auf einer Seite.
- **Animationen** kommen aus `Motion`, zum Beispiel `Motion.standard`, damit „Bewegung reduzieren“ überall greift.
- **Ausgaben** mit `print` gibt es nur in `Sources/Diagnostics`, denn jede andere Ausgabe könnte private Datei- oder
  Ordnernamen zeigen.

## <img src="assets/icons/translations.svg" height="33" align="absmiddle" alt="">Texte nur über Übersetzungen

Im Code steht kein Text, den man in der App liest. Jeder sichtbare Text hat einen englischen Schlüssel in
`TextKey.swift`, zum Beispiel `TextKey.categories.translated`, und die Texte selbst stehen in den 20 Dateien unter
`Resources`. Deutsche Wörter tauchen im Code deshalb nirgends auf. Ausgaben für Entwickler, etwa vom Selbsttest, sind
auf Englisch.

## <img src="assets/icons/steps.svg" height="33" align="absmiddle" alt="">Kleine, klar getrennte Schritte

Eine Funktion, die einen Ablauf steuert, liest sich wie eine Liste. Jeder Schritt ist eine eigene Funktion mit einem
sprechenden Namen, und die steuernde Funktion entscheidet nur, welcher Schritt wann laufen darf:

```swift
func run() async {
    await scanEveryArea()
    await visitEveryPage()
    guard hasFullDiskAccess else { return }
    await cleanUpWithoutDeleting()
}
```

Lange Ketten aus vielen Aufrufen hintereinander teilen wir in benannte Zwischenschritte. Eine Funktion bleibt unter
40 Zeilen und unter zehn Verzweigungen; darüber meldet sich SwiftLint. Bei SwiftUI fassen wir
Modifikatoren, die zusammengehören, in einer eigenen Eigenschaft oder einem eigenen Modifikator zusammen, damit eine
Ansicht nicht zu einer langen Treppe wird.

## <img src="assets/icons/deadcode.svg" height="33" align="absmiddle" alt="">Kein toter Code

Was nicht benutzt wird, wird gelöscht und nicht auskommentiert. Toter Code macht die App größer und führt in die
Irre, weil man ihn für wichtig hält. Wer ihn später wieder braucht, findet ihn in der Versionsgeschichte von Git. Das
gilt auch für Texte: Ein Schlüssel, den die App nirgends zeigt, verschwindet samt seinen Übersetzungen.

## <img src="assets/icons/comments.svg" height="33" align="absmiddle" alt="">Kommentare nur für das Unsichtbare

Ein guter Name ersetzt einen Kommentar. Kommentare bleiben für Regeln, die man im Code nicht sieht, etwa warum ein
Diagramm ohne Animation zeichnet. Die Geschichte, wie ein Fehler entstanden ist, gehört in die Commit-Nachricht oder in
die [Architektur-Beschreibung](ARCHITECTURE.md).

## <img src="assets/icons/tests.svg" height="33" align="absmiddle" alt="">Tests

Die Tests liegen in `Tests/SpeicherExplorerTests` und nutzen Apples Test-Framework Swift Testing. Jeder Test hat einen
Namen, der als ganzer Satz sagt, was gelten soll, zum Beispiel „Only emptying the Trash needs a deliberate click in
the cleaner“. Getestet wird alles, was ohne Bildschirm eine feste Antwort hat: der Ordnerbaum, die Suche, die
Seitenliste, die Kategorien, die Größenklassen, die Legende, die Zusammenfassung, die Gestaltungswerte, der Kontrast
und die Übersetzungen.

Tests greifen nie auf die echte Festplatte zu und benutzen keine echten Datei- oder Ordnernamen. Einen Ordnerbaum baut
ein Test deshalb von Hand auf, mit erfundenen Namen wie `film.mov`. In Tests dürfen Beispielwerte als Zahl dastehen,
weil sie dort selbst die Erklärung sind. Wer eine Regel im Code ändert oder ergänzt, schreibt oder ändert den
passenden Test gleich mit.

## <img src="assets/icons/checks.svg" height="33" align="absmiddle" alt="">So prüfst du deinen Code

Vor jedem Beitrag startest du die Prüfkette. Sie darf keinen einzigen Fehler und keine einzige Warnung melden.
Dahinter steckt das Skript `scripts/inspect.py`. Einzelne Schritte startest du mit deren Namen, etwa
`scripts/inspect.py tests rules`.

```bash
make check
```

Das Skript führt neun Prüfungen nacheinander aus:

1. **Form:** `swift format lint --strict` meldet jede Abweichung von der einheitlichen Form.
2. **Länge und Verschachtelung:** SwiftLint meldet Funktionen über 40 Zeilen, Closures über 30 Zeilen, zu viele
   Verzweigungen in einer Funktion und zu tief verschachtelte Typen. Die Grenzen stehen in `.swiftlint.yml`.
3. **Compiler:** Die App wird mit `-warnings-as-errors` gebaut, sodass schon eine Warnung als Fehler zählt.
4. **Tests:** `swift test` startet alle Tests aus `Tests/SpeicherExplorerTests`.
5. **Hausregeln:** Zahlen ohne Namen, Farben außerhalb von `Theme.swift`, deutscher Text im Code, `$0`, Namen aus ein
   oder zwei Buchstaben und Zeilen über 100 Zeichen.
6. **Gestaltung:** Schriften ohne Textrolle, Symbolnamen außerhalb von `Symbols`, Animationen außerhalb von `Motion`,
   ausgeschriebene Texte auf dem Bildschirm und Ausgaben außerhalb der Diagnose.
7. **Toter Code:** jede Funktion, jeder Wert und jeder Text, der zwar angelegt, aber nirgends benutzt wird.
8. **Übersetzungsdateien:** `plutil -lint` prüft, ob alle 20 Übersetzungen und die `Info.plist` lesbar sind.
9. **Skripte:** `bash -n` und `make -n` prüfen die Shell-Skripte und das `Makefile` auf Schreibfehler.

Ob jeder Text in allen 20 Sprachen vorhanden ist und ob jede Farbe den Kontrast erreicht, prüfen die Tests im vierten
Schritt. Wie viel des Codes die Tests erreichen, zeigt `make coverage` je Ordner an.

Auf GitHub läuft dieselbe Prüfung bei jedem Pull Request von selbst, beschrieben in
`.github/workflows/checks.yml`. Meldet sie auch nur einen Fund, wird der Pull Request rot, und der Beitrag muss
nachgebessert werden, bevor er übernommen wird. Ob Namen verständlich sind und ob ein Schritt gut
geschnitten ist, kann kein Skript beurteilen. Darauf achten wir beim Lesen eines Beitrags.

<p align="center">
  <img src="assets/banner-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · Sieh auf einen Blick, wo dein Speicher steckt.</b><br>
  <sub><a href="README.md">Übersicht</a> · <a href="CONTRIBUTING.md">Mitmachen</a> · <a href="ARCHITECTURE.md">Architektur</a> · <a href="CODE_STYLE.md">Code-Regeln</a> · <a href="CODE_OF_CONDUCT.md">Verhaltensregeln</a></sub><br>
  <sub>© 2026 Robertwlt03 · Veröffentlicht unter der <a href="LICENSE">MIT-Lizenz</a> · Für macOS 27 auf Macs mit Apple-Chip</sub>
</p>
