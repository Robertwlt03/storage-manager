<p align="center">
  <img src="assets/banner-mitmachen.svg" alt="Mitmachen beim Speicher-Explorer. So baust, prüfst und erweiterst du die App." width="100%">
</p>

<p align="center"><a href="CONTRIBUTING.md">Deutsch</a> · <a href="CONTRIBUTING.en.md">English</a></p>

Schön, dass du mithelfen möchtest. Diese Anleitung erklärt, wie du die App baust, wo du was findest und worauf du
achten solltest. Wie der Code aufgebaut ist und welche Regeln absichtlich gelten, steht in der
[Architektur-Beschreibung](ARCHITECTURE.md).

## <img src="assets/icons/requirements.svg" height="33" align="absmiddle" alt="">Was du brauchst

Du brauchst einen Mac mit Apple-Chip und macOS 27, denn die App nutzt Swift 6.4, Liquid Glass und die Neuerungen von
macOS 27. Genauso läuft sie später bei allen, die sie benutzen.

Zum Bauen brauchst du außerdem Xcode 27 aus dem App Store. Du musst Xcode nie öffnen, es dient nur als Werkzeugkasten:
Die Command Line Tools allein reichen nicht mehr, weil SwiftUI für macOS 27 Makros nutzt, die nur Xcode mitbringt.
Nach der Installation stellst du die Werkzeuge einmalig auf Xcode um. Für die Prüfkette kommt noch SwiftLint dazu.

```bash
sudo xcode-select --switch /Applications/Xcode.app
```

```bash
brew install swiftlint
```

## <img src="assets/icons/editor.svg" height="33" align="absmiddle" alt="">Dein Editor

Du kannst mit jedem Editor arbeiten, den du magst, denn das Projekt ist ein reines Swift-Paket mit einer
`Package.swift`. Gebaut, getestet und geprüft wird immer über die Kommandozeile, und dort ist es egal, womit du den
Code schreibst:

- **Xcode** öffnet die `Package.swift` direkt, du brauchst kein eigenes Xcode-Projekt.
- **VS Code, Cursor und Zed** verstehen Swift mit der offiziellen Swift-Erweiterung beziehungsweise von Haus aus.
- **Neovim, Helix und andere Editoren** sprechen mit `sourcekit-lsp`. Dieser Sprachserver ist in Xcode schon
  enthalten.
- **JetBrains-IDEs wie PhpStorm** können die Dateien bearbeiten, bieten für Swift aber keine eigene Unterstützung mehr.
  Bauen und prüfen läuft dort über das Terminal.

Damit der Code trotzdem überall gleich aussieht, legt die Datei `.swift-format` die Form fest. Viele Editoren lesen sie
beim Speichern von selbst, und sonst bringt `make format` alles in Form.

## <img src="assets/icons/terminal.svg" height="33" align="absmiddle" alt="">Kurze Befehle

Lange Befehle musst du dir nicht merken. Wie bei den Skripten von npm steht jeder Ablauf als kurzer Befehl im
`Makefile`, und `make` allein zeigt dir die Liste:

| Befehl | Was er tut |
| --- | --- |
| `make run` | baut die App, schließt sie, falls sie offen ist, und öffnet die neue |
| `make demo` | baut die App ohne Zertifikat und öffnet sie im Vorführmodus mit erfundenen Daten |
| `make snapshots` | freiwillig: fotografiert jede Seite im Vorführmodus, hell und dunkel, und vergleicht die Bilder |
| `make restart` | schließt die App, falls sie offen ist, und öffnet sie neu, ohne zu bauen |
| `make build` | baut die App und zeichnet ihr Symbol |
| `make check` | startet die ganze Prüfkette, genau wie auf GitHub |
| `make test` | startet nur die Tests |
| `make coverage` | zeigt, wie viel des Codes die Tests je Ordner erreichen |
| `make format` | bringt alle Swift-Dateien in die gemeinsame Form |
| `make selftest` | startet die gebaute App als Selbsttest, misst echte Ordner und vergleicht mit `du` |
| `make stress` | öffnet eine zweite App, die so schnell wie möglich durch alle Seiten klickt |
| `make identity` | legt einmalig dein eigenes Zertifikat in einem eigenen Schlüsselbund an |
| `make release` | erstellt die DMG zum Weitergeben im Ordner `dist` |
| `make clean` | löscht alles, was beim Bauen entsteht |

Die Befehle rufen nur die Skripte auf, die ohnehin im Projekt liegen. Du kannst sie also auch weiterhin direkt
benutzen, etwa `./build.sh` oder `scripts/check.py tests`.

## <img src="assets/icons/build.svg" height="33" align="absmiddle" alt="">Die App bauen und starten

Mit einem einzigen Befehl baust du die App und startest sie. `make run` legt sie in den Ordner `build`, schließt eine
schon geöffnete App und öffnet danach die neue.

```bash
make run
```

Ohne weitere Angaben wird die App nur behelfsmäßig signiert. Dann fragt macOS nach jedem Bauen erneut nach dem
Festplattenvollzugriff. Wenn dich das stört, legst du einmalig ein eigenes Zertifikat an. `make identity` erzeugt es in
einem eigenen kleinen Schlüsselbund nur für dieses Projekt und trägt alles Nötige in die Datei `local.mk` ein, die Git
ignoriert. Damit macOS den Festplattenvollzugriff über alle Builds behält, bittet macOS dabei einmal in einem normalen Dialog um
dein Passwort, um dem Zertifikat für das Signieren zu vertrauen. Beim Bauen entsperrt `build.sh` den Schlüsselbund
selbst, dein Passwort wird danach nie wieder gebraucht. Nach dem nächsten `make run` setzt du den Festplattenvollzugriff ein letztes
Mal, danach bleibt er bei jedem Bauen erhalten.

```bash
make identity
```

## <img src="assets/icons/demo.svg" height="33" align="absmiddle" alt="">Vorführmodus

Im Vorführmodus zeigt die App jede Seite mit erfundenen Daten: einen ausgedachten Ordnerbaum, einen festen
Datenträger, ein paar Apps und Kopien. Sie misst dabei nichts, liest keine eigenen Dateien und kann nichts löschen,
denn alle Knöpfe zum Aufräumen und Löschen bleiben wirkungslos. Deshalb brauchst du dafür weder den
Festplattenvollzugriff noch dein Zertifikat, und auf dem Bildschirm erscheinen keine privaten Namen. `make demo` baut
die App dafür in einen eigenen Ordner, sodass deine signierte App unberührt bleibt.

```bash
make demo
```

So prüfst du vor jedem Beitrag das Aussehen der Seiten, die du geändert hast, im hellen und im dunklen
Erscheinungsbild. Auch die Bildschirmfotos für das README entstehen im Vorführmodus. Die erfundenen Daten stehen in
`Sources/Diagnostics/DemoData.swift`.

Wer mag, lässt den Vergleich auch vom Mac machen. `make snapshots RECORD=1` fotografiert jede Seite einmal hell und
einmal dunkel und legt die Bilder als Vorlage in den Ordner `snapshots`, den git nicht beachtet, weil die Bilder von
deinem Bildschirm und Hintergrundbild abhängen. Nach einer Änderung fotografiert `make snapshots` die Seiten erneut
und nennt jede Seite, auf der sich mehr als ein Prozent der Bildpunkte geändert hat; die geänderten Stellen zeigt es
rot in `snapshots/difference`. Dafür fragt macOS beim ersten Mal, ob dein Terminal den Bildschirm aufnehmen darf. Das
ist der einzige Grund für diese Freigabe, und deshalb ist der Vergleich freiwillig und läuft nicht auf GitHub.

## <img src="assets/icons/checks.svg" height="33" align="absmiddle" alt="">Prüfungen vor jedem Beitrag

Vor jedem Beitrag startest du die Prüfkette. Sie prüft die Form, baut die App mit Warnungen als Fehler, startet alle
Tests und kontrolliert die [Code-Regeln](CODE_STYLE.md), also Namen, Zahlen, Farben, Gestaltung, Texte und toten
Code. Sie darf keinen einzigen Fehler und keine einzige Warnung melden. Auf GitHub läuft dieselbe Prüfung bei jedem
Pull Request von selbst und markiert ihn rot, solange noch etwas zu verbessern ist.

```bash
make check
```

Die Tests in der Prüfkette kontrollieren auch, ob jeder Text in allen 20 Sprachen vorhanden ist und gleich viele
Platzhalter hat, und ob jede Textfarbe in hellem und dunklem Erscheinungsbild einen Kontrast von mindestens 4,5 zu 1
erreicht. Wenn du eine Regel änderst, ergänzt du den passenden Test, und `make coverage` zeigt dir, was noch ungetestet
ist.

Zwei weitere Prüfungen startest du bei Bedarf selbst. Der Selbsttest misst echte Ordner und vergleicht das Ergebnis
mit dem Befehl `du`. Der Belastungstest bedient die laufende App wie ein sehr schneller Mensch und versucht, Fehler
auszulösen. Beide geben nur Anzahlen und Größen aus, niemals Datei- oder Ordnernamen.

Beide laufen als die gebaute App und nutzen deren Festplattenvollzugriff. Fehlt er, brechen sie sofort ab, bevor
macOS für jeden geschützten Ordner einzeln nachfragt. Baue die App deshalb vorher mit deinem eigenen Zertifikat, damit
der Vollzugriff über alle Builds erhalten bleibt, und starte den Selbsttest nie als nacktes Programm aus
`.build/release`, denn dann fragt macOS hunderte Male.

```bash
make selftest
```

```bash
make stress
```

## <img src="assets/icons/rules.svg" height="33" align="absmiddle" alt="">Regeln, die immer gelten

- **Keine Namen ausgeben:** Ausgaben, Protokolle und Tests zeigen nie Namen von Dateien oder Ordnern, sondern nur
  Anzahlen und Größen. Was auf der Festplatte liegt, ist privat.
- **Nichts löschen ohne Rückfrage:** Die App entfernt nur nach einer Bestätigung etwas, und Kopien einer App nur, wenn
  diese App nicht läuft. Tests löschen nie etwas.
- **Texte in allen Sprachen:** Jeder neue Text bekommt einen englischen Schlüssel in `TextKey` und eine Zeile in allen
  20 Dateien unter `Resources`. Deutsch und Englisch sind die Vorlage. Bei den übrigen Sprachen freuen wir uns besonders über
  Verbesserungen von Muttersprachlern.
- **Code auf Englisch, Anleitungen auf Deutsch und Englisch:** Namen, Kommentare und Commit-Nachrichten schreibst du auf
  Englisch. Anleitungen entstehen auf Deutsch, und jede hat einen englischen Zwilling (`*.en.md`), der mit ihr
  geändert wird.
- **Commit-Nachrichten in fester Form:** Der Betreff lautet etwa `fix(scan): canceled scans stop at once`, also die
  Art der Änderung (`feat`, `fix`, `docs`, `refactor`, `test` …), vielleicht der betroffene Teil in Klammern und dann
  in einem Satz, was sich ändert. Nach einer Leerzeile erklärt der Text, warum, und zwar auf Englisch.
- **Lesbarer Code:** Ausgeschriebene Namen in Alltagssprache, keine Zahlen ohne Namen, Farben nur aus `Theme` und
  kleine, klar getrennte Schritte. Die Einzelheiten stehen in den [Code-Regeln](CODE_STYLE.md).

## <img src="assets/icons/newpage.svg" height="33" align="absmiddle" alt="">Eine neue Seite hinzufügen

1. Lege in `Pane` einen neuen Fall an und gib ihm in der Tabelle `details` seinen Schlüssel, Titel, Info-Text und sein
   Symbol.
2. Schreibe die Seite als eigene Datei in einem neuen Ordner unter `Sources/Features`.
3. Trage sie in `Pane.page` in der Datei `Features/Pages.swift` ein.
4. Lege die neuen Texte in allen Sprachen an.

Die Seitenleiste baut sich aus `Pane` von selbst, dort ist nichts weiter zu tun.

## <img src="assets/icons/components.svg" height="33" align="absmiddle" alt="">Bausteine benutzen

Alle Bausteine der Oberfläche liegen im Namensraum `UI`. Wenn du `UI.` tippst, siehst du sie alle. Jeder Baustein hat
wenige feste Varianten, damit gleiche Dinge überall gleich aussehen:

| Baustein | Wofür | Varianten |
| --- | --- | --- |
| `UI.Page` | eine scrollende Seite mit Kopfzeile | mit oder ohne Optionen |
| `UI.Card` | eine abgerundete Fläche | mit oder ohne Überschrift |
| `UI.Rows`, `UI.NavigationRow`, `UI.Fields` | Zeilen mit Trennlinien | Navigation oder Bezeichnung mit Wert |
| `UI.Icon` | jedes Symbol und Bild | Art und Größe von sehr klein bis groß |
| `UI.Note` | eine Zeile Information | Hinweis, in Arbeit, gut, Warnung, Fehler |
| `UI.Placeholder` | Ersatz für fehlenden Inhalt | leer, lädt, nicht gemessen, auf einer Seite oder Karte |
| `UI.Tile`, `UI.KeyFigure` | Kacheln | Rasterkachel oder Kennzahl |
| `UI.ActionButton` | ein Knopf mit Text | normal, hervorgehoben, bestätigend, still, Inhalt |

Abstände nimmst du aus `Space`, Icon-Größen aus `IconSize` und Schriften über `textRole` aus `TextRole`. Feste Zahlen
oder einzelne Schriften direkt im Code vermeiden wir, denn dann sieht ein Teil der App bald anders aus als der Rest.

## <img src="assets/icons/issues.svg" height="33" align="absmiddle" alt="">Fehler melden und Ideen vorschlagen

Fehler und Wünsche meldest du über die Issues auf GitHub. Für beides gibt es eine Vorlage, die nach den wichtigsten
Angaben fragt. Bitte füge keine Bildschirmfotos mit privaten Datei- oder Ordnernamen an.

## <img src="assets/icons/community.svg" height="33" align="absmiddle" alt="">Umgang miteinander

Wir gehen freundlich und respektvoll miteinander um. Die Einzelheiten stehen in den [Verhaltensregeln](CODE_OF_CONDUCT.md).

<p align="center">
  <img src="assets/banner-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · Sieh auf einen Blick, wo dein Speicher steckt.</b><br>
  <sub><a href="README.md">Übersicht</a> · <a href="CONTRIBUTING.md">Mitmachen</a> · <a href="ARCHITECTURE.md">Architektur</a> · <a href="CODE_STYLE.md">Code-Regeln</a> · <a href="CODE_OF_CONDUCT.md">Verhaltensregeln</a></sub><br>
  <sub>© 2026 Robertwlt03 · Veröffentlicht unter der <a href="LICENSE">MIT-Lizenz</a> · Für macOS 27 auf Macs mit Apple-Chip</sub>
</p>
