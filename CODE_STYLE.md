<p align="center">
  <img src="assets/banner-code-regeln.svg" alt="Code-Regeln des Speicher-Explorers. So schreiben wir Code, den jeder lesen kann." width="100%">
</p>

<p align="center"><a href="CODE_STYLE.md">Deutsch</a> · <a href="CODE_STYLE.en.md">English</a></p>

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
- **Liquid Glass** kommt nur über `.surface()` für Karten und `.appButton(...)` für Knöpfe. Eigenes Glas, Materialien
  oder Hintergründe unter Karten legt keine Seite selbst an.
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
Dahinter steckt das Skript `scripts/check.py`. Einzelne Schritte startest du mit deren Namen, etwa
`scripts/check.py tests rules`.

```bash
make check
```

Die Ausgabe ist so gegliedert, dass man sie auf einen Blick liest. Jeder Schritt bekommt eine Zeile mit einem
grünen Haken ✔ oder einem roten Kreuz ✘, der Zahl seiner Funde und seiner Dauer. Unter einem Schritt mit Funden
stehen diese nach Datei geordnet, jeweils mit der Zeilennummer und dem, was falsch ist. Am Ende fasst ein Rahmen
zusammen: grün, wenn alle Schritte bestanden sind, sonst rot mit den Schritten und ihren Funden. Farben erscheinen
im Terminal und auf GitHub, und dort steht jeder Fund zusätzlich direkt an seiner Zeile im Pull Request.
`NO_COLOR=1` schaltet die Farben ab.

Das Skript führt dreiundzwanzig Prüfungen nacheinander aus:

1. **Form:** `swift format lint --strict` meldet jede Abweichung von der einheitlichen Form.
2. **Länge und Verschachtelung:** SwiftLint meldet Funktionen über 40 Zeilen, Closures über 30 Zeilen, zu viele
   Verzweigungen in einer Funktion und zu tief verschachtelte Typen. Die Grenzen stehen in `.swiftlint.yml`.
3. **Compiler:** Die App wird mit `-warnings-as-errors` gebaut, sodass schon eine Warnung als Fehler zählt.
4. **Tests:** `swift test` startet alle Tests aus `Tests/SpeicherExplorerTests`, ebenfalls ohne eine Warnung.
5. **Testabdeckung:** Die Tests müssen in jedem Ordner mit Logik einen Mindestanteil der Zeilen erreichen. Die Werte
   stehen knapp unter dem heutigen Stand in `MINIMUM_COVERAGE` (`scripts/checks/tools.py`), sodass die Abdeckung nur
   wachsen kann; die Ordner mit Ansichten sind mit Grund ausgenommen. Ein neuer Ordner ohne Regel wird gemeldet.
6. **Hausregeln:** Zahlen ohne Namen, Farben außerhalb von `Theme.swift`, deutscher Text im Code, `$0`, Namen aus ein
   oder zwei Buchstaben, Zeilen über 100 Zeichen und vergessene vorübergehende Debug-Zeilen. Das gilt auch für die
   Swift-Skripte im Ordner `scripts`.
7. **Gestaltung:** Schriften ohne Textrolle, Symbolnamen außerhalb von `Symbols`, eigenes Glas oder eigene
   Hintergründe, Animationen außerhalb von `Motion`, ausgeschriebene Texte auf dem Bildschirm und Ausgaben außerhalb
   der Diagnose. Ausgeschriebene Texte findet die Prüfung über den Compiler-Index: jeden Aufruf von SwiftUI, dessen
   erstes Argument ein Text in Anführungszeichen ist, also auch Elemente, die es heute noch nicht gibt.
8. **Bedienhilfen:** Jedes Bild entscheidet, was VoiceOver damit tut: Es trägt Bedeutung und bekommt mit
   `.accessibilityLabel` einen Namen, oder es schmückt einen Text daneben und schweigt mit
   `.accessibilityHidden(true)` (`scripts/checks/accessibility.py`).
9. **Flache Methoden:** In einer Methode dürfen höchstens zwei Blöcke ineinander stecken, also etwa eine Schleife
   und darin ein `if`. Als Block zählt alles, was über mehrere Zeilen geht: `if`, `else`, `switch`, Schleifen,
   Closures und innere Funktionen. Ein tieferer Teil gehört in eine eigene Methode mit sprechendem Namen, und eine
   Funktion in einer Funktion in einer Funktion gibt es nicht. Das gilt für Swift, Python und Shell
   (`scripts/checks/nesting.py`). Was eine Methode ist, liest die Prüfung an ihrem Platz ab und nicht an einem
   Schlüsselwort: Alles, was direkt in einem Typ geöffnet wird, zählt als Methode, auch eine Art von Deklaration,
   die Swift erst später einführt. In Python zählt jede Anweisung mit eigenem Block.
10. **Kein doppelter Code:** Stehen dieselben sechs Zeilen mit Gehalt an zwei Stellen, gehören sie in eine gemeinsame
   Methode. Zahlen und Texte gelten dabei als gleich, sodass auch eine Kopie mit geändertem Wert auffällt; leere
   Zeilen, Kommentare und einzelne Klammern zählen nicht (`scripts/checks/duplicates.py`).
11. **Architektur:** Jeder Ordner unter `Sources` ist ein Teil der App und darf nur die Teile benutzen, die die
   Tabelle in `scripts/checks/architecture.py` erlaubt, etwa das Designsystem keine Seiten und keinen Zustand. Ein
   neuer Ordner braucht dort erst einen Platz, sonst meldet ihn die Prüfung.
12. **Versprechen der App:** Netzwerk-Schnittstellen kommen im Code nicht vor, denn die App bleibt auf dem Mac.
   Dateien löschen oder in den Papierkorb legen nur die drei Dienste, die vorher nachfragen
   (`scripts/checks/promises.py`).
13. **Festplatte abseits des Hauptthreads:** Jeder Zugriff auf die Festplatte steht in Code, der als `nonisolated`
   gekennzeichnet ist oder mit `Task.detached` läuft, denn der Hauptthread zeichnet das Fenster. Ausgenommen sind nur
   die Diagnose-Werkzeuge (`scripts/checks/disk_access.py`).
14. **Toter Code:** jede Funktion, jeder Typ, jeder Wert und jeder Text, den der eigene Code nirgends benutzt, und
   jede Eigenschaft, die nur beschrieben, aber nie gelesen wird. Die Prüfung liest dafür den Index, den der Compiler
   beim Bauen anlegt (`scripts/checks/index_store.py`). So verwechselt sie keine gleichnamigen Eigenschaften, und
   was nur die Tests benutzen, zählt ebenfalls als tot. Für jede Art von Symbol ist festgelegt, ob sie geprüft wird
   oder aus welchem Grund nicht. Taucht eine Art auf, für die das noch niemand entschieden hat, meldet die Prüfung
   sie, statt sie zu überspringen.
15. **Keine ungenutzten Dateien:** Jedes Bild und jede andere Mediendatei muss in einer anderen Datei mit ihrem Namen
   vorkommen, sonst ist sie toter Ballast (`scripts/checks/unused_files.py`).
16. **Sprache:** Jeder Name, den wir anlegen, wird in seine Wörter zerlegt (`fileCount`: file, count). Jedes Wort
   muss amerikanisches Englisch oder ein bekannter Fachbegriff sein und darf keine Abkürzung sein, also `temporary`
   statt `temp` und `maximum` statt `max`. Die Kommentare werden genauso gelesen. Die Wörter prüft die
   Rechtschreibprüfung von macOS (`scripts/checks/language.py`). Fachbegriffe wie `plist` oder `codesign` stehen in
   keiner Liste: Als bekannt gilt, was in den Namen der benutzten Schnittstellen von Apple und Python vorkommt, was
   als Befehl auf dem Mac installiert ist, die Dateiendungen des Projekts und der Name der App. Nur die verbotenen
   Abkürzungen bleiben eine Liste, weil keine Quelle verlässlich sagt, ob ein Wort eine Abkürzung ist.
17. **Übersetzungsdateien:** `plutil -lint` prüft, ob alle 20 Übersetzungen und die `Info.plist` lesbar sind.
18. **Vollständige Übersetzungen:** Ein Text, der in einer Sprache wortgleich mit dem Englischen ist, wird gemeldet,
   wenn die Rechtschreibprüfung von macOS eines seiner Wörter in dieser Sprache nicht kennt. Begriffe wie „iCloud
   Drive“, die in den meisten Sprachen gleich lauten, sind ausgenommen (`scripts/checks/translations.py`).
19. **Anleitungen:** Jede deutsche Anleitung und ihr englischer Zwilling haben denselben Aufbau, also dieselben
   Abschnitte mit denselben Symbolen, Bilder, Codeblöcke und Tabellenzeilen. Jeder Link führt zu einer Datei, die es
   gibt, und die englischen Texte schreiben amerikanisch (`scripts/checks/guides.py`).
20. **Geheimnisse:** Keine Datei, die git kennt, enthält einen privaten Schlüssel, einen Zugangsschlüssel oder ein
   ausgeschriebenes Passwort. Jede Einstellungsdatei, die das `Makefile` einliest, wie `local.mk`, muss von git
   ignoriert werden (`scripts/checks/secrets.py`).
21. **Sicherheit:** Die App hat Festplattenvollzugriff, deshalb darf kein fremder Code in sie hinein. Sie wird mit der
   gehärteten Laufzeit signiert (`--options runtime`), sodass sich keine Bibliothek einschleusen lässt. Kein Code
   startet eine Shell, die Text als Befehle liest, kein Skript führt Text als Code aus oder lädt Skripte aus dem
   Internet direkt in eine Shell, und niemand benutzt feste Pfade im gemeinsamen Ordner für vorübergehende Dateien.
   Jedes Shell-Skript beginnt mit `set -euo pipefail`. Wo Swift seine Sicherheit abschaltet, etwa mit
   `nonisolated(unsafe)` oder `@unchecked Sendable`, steht ein Kommentar mit dem Grund. Der Workflow auf GitHub hat
   nur Leserechte, bindet jede Aktion an einen festen Commit, installiert Werkzeuge in fester Version mit Prüfsumme
   und gibt Text aus fremden Pull Requests nie in einen Befehl (`scripts/checks/security.py`).
22. **Skripte:** Auch die Skripte und das `Makefile` bleiben unter 100 Zeichen pro Zeile, und jedes beginnt mit dem
   gemeinsamen Kopf. `bash -n`, `python3 -m py_compile`, `swiftc -typecheck` und `make -n` prüfen sie auf
   Schreibfehler.
23. **Einheitliche Ausgabe:** Alles, was ein Befehl in die Konsole schreibt, sieht gleich aus: eine Überschrift,
   Zeilen mit einem Zeichen (✔ fertig, ✘ fehlgeschlagen, › läuft) und gedimmten Details, gedimmte Hinweise und ein
   Rahmen, der am Ende zusammenfasst. Die Bausteine stehen einmal je Sprache: `scripts/console.sh` für die Shell und
   das `Makefile`, `scripts/checks/console.py` für Python und `Sources/Diagnostics/Console.swift` für die App. Jedes
   andere `echo`, `printf` oder `print` wird gemeldet. Was ein anderes Programm liest statt eines Menschen, nennt
   das Skript in seinem Kopf mit `Output:` und schreibt es schlicht (`scripts/checks/console_output.py`).
24. **Commit-Nachrichten:** Jeder Commit hat einen Betreff wie `fix(scan): what changed`, also eine Art nach
   Conventional Commits, vielleicht einen Teil in Klammern und dann die Änderung. Danach folgen eine Leerzeile und
   Zeilen bis 100 Zeichen, alles auf Englisch in amerikanischer Schreibweise: Ein Wort, das weder das Wörterbuch
   noch der Code des Projekts kennt, etwa ein deutsches, wird gemeldet. Die Regel gilt ab dem Commit, der sie eingeführt hat; geprüft werden
   die Commits, die noch nicht auf dem `main` von GitHub liegen (`scripts/checks/commits.py`).
25. **Probe:** Im Ordner `scripts/checks/samples` steht ein kleines eigenes Paket mit schlechten Beispielen, das nie
   zur App gehört. Jede schlechte Zeile trägt einen Vermerk `expect:` mit dem Fund, den die Prüfung dort melden muss.
   Findet eine Prüfung ihren Fehler nicht mehr, oder meldet sie etwas, das niemand eingebaut hat, schlägt dieser
   Schritt fehl. Wer eine Regel ergänzt, baut ihren Fehler mit Vermerk dort ein.

Jedes Skript ist gleich aufgebaut, damit man nach dem ersten auch alle anderen versteht. Oben steht ein Kopf, der in
einem Satz sagt, was das Skript tut, dazu die Zeilen `Start:` (wie man es startet) und `Needs:` (was es braucht).
Danach folgen die Einstellungen unter `MARK: Settings`: Jede Zahl und jedes Muster hat dort einen Namen und eine
Erklärung. Dann kommen die Schritte als kleine, benannte Funktionen, und ganz unten steht unter `MARK: Run` der
Ablauf als Liste dieser Schritte. Suchmuster werden über mehrere Zeilen mit einem Kommentar pro Teil geschrieben, und
Namen sind ausgeschrieben, also `BUILD_FOLDER` statt `BUILD_DIR`. Die Prüfkette selbst liegt aufgeteilt in
`scripts/checks/`, ein Modul pro Thema.

Ob jeder Text in allen 20 Sprachen vorhanden ist und ob jede Farbe den Kontrast erreicht, prüfen die Tests im vierten
Schritt. Wie viel des Codes die Tests erreichen, zeigt `make coverage` je Ordner an.

Auf GitHub läuft dieselbe Prüfung bei jedem Pull Request von selbst, beschrieben in
`.github/workflows/checks.yml`. Meldet sie auch nur einen Fund, wird der Pull Request rot, und der Beitrag muss
nachgebessert werden, bevor er übernommen wird. Ob Namen verständlich sind und ob ein Schritt gut
geschnitten ist, kann kein Skript beurteilen, und auch das Aussehen des Glases sieht nur das Auge: Dafür öffnest
du die geänderten Seiten mit `make demo`. Darauf achten wir beim Lesen eines Beitrags.

<p align="center">
  <img src="assets/banner-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · Sieh auf einen Blick, wo dein Speicher steckt.</b><br>
  <sub><a href="README.md">Übersicht</a> · <a href="CONTRIBUTING.md">Mitmachen</a> · <a href="ARCHITECTURE.md">Architektur</a> · <a href="CODE_STYLE.md">Code-Regeln</a> · <a href="CODE_OF_CONDUCT.md">Verhaltensregeln</a></sub><br>
  <sub>© 2026 Robertwlt03 · Veröffentlicht unter der <a href="LICENSE">MIT-Lizenz</a> · Für macOS 27 auf Macs mit Apple-Chip</sub>
</p>
