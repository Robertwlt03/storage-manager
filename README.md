# Speicher-Explorer

Eine native macOS-App, die zeigt, wo auf dem Mac der Speicherplatz steckt. Sie misst alle wichtigen Bereiche in einem
einzigen, energiesparenden Durchgang, ordnet den belegten Platz in Kategorien wie in den Systemeinstellungen unter
„Speicher“ und lässt dich danach ohne erneutes Messen durch alle Ordner klicken und suchen. Die App schickt nichts weg
und löscht nur an einer Stelle, nämlich bei den Prüfkopien, und das erst nach einer ausdrücklichen Bestätigung.

## Bereiche

- **Überblick**: der Startdatenträger mit einem gestapelten Balken und die Kategorien nach Größe sortiert. Die
  Kategorien entstehen aus Regeln für bekannte Ordner; was auf einem Mac nicht existiert, bleibt einfach weg.
- **Ordner**: eine native Tabelle mit Finder-Symbolen, sortierbar nach Name, Größe, Anteil und Dateizahl. Doppelklick
  geht tiefer; das Kontextmenü zeigt „Im Finder zeigen“, „Informationen“ und „Pfad kopieren“.
- **Große Dateien**: alle Dateien ab einer wählbaren Größe, sofort aus der letzten Messung.
- **Suche** (Feld oben rechts): findet Ordner und Dateien ab 1 MB nach Namen, wahlweise nur Ordner oder nur Dateien.
- **Temporärer Bereich** und **Prüfkopien**: der versteckte Bereich unter `/private/var/folders/…` und die Kopien, die
  macOS beim Prüfen von App-Signaturen anlegt (für jede App, Löschen nur bei beendeter App und nach Bestätigung).
- **Datenträger**: jeder angeschlossene Datenträger mit Kapazität, belegtem, löschbarem und freiem Platz.

## Einstellungen (⌘,)

- **Allgemein**: Sprache (wie das System, Deutsch oder Englisch; die Änderung wirkt sofort) und der Stand des
  Festplattenvollzugriffs.
- **Darstellung**: Erscheinungsbild, Liquid Glass an oder aus (ab macOS 26), Diagrammfarben und binäre Einheiten.
- **Messen**: beim Start automatisch messen, im Stromsparmodus pausieren, energiesparend messen und zusätzliche Ordner.

## Berechtigungen

Ohne Festplattenvollzugriff fragt macOS einzeln nach Schreibtisch, Dokumenten, Downloads, iCloud Drive, den Daten
anderer Apps und externen Datenträgern. Deshalb bietet die App bei jedem Start, solange der Vollzugriff fehlt, an,
ihn einmal zu erteilen: „Systemeinstellungen öffnen“ (blau) führt zum Schalter, „App neu starten“ (grün) übernimmt
ihn, denn macOS gibt ihn erst einem neuen Prozess. Wer das nicht möchte, fährt ohne Vollzugriff fort und bekommt die
einzelnen Abfragen. Ist der Vollzugriff erteilt, erscheint das Fenster nicht mehr.

Einmal erteilte Freigaben gelten, solange die App mit derselben Signatur gebaut wird. Ad hoc signierte Neubauten
gelten für macOS als neue App und fragen erneut. Für eine feste Identität beim Entwickeln:

```bash
scripts/create-signing-identity.sh
```

```bash
SIGN_IDENTITY="Speicher-Explorer Dev" ./build.sh
```

Beim ersten Signieren fragt macOS einmal, ob `codesign` den Schlüssel benutzen darf („Immer erlauben“). Zum Weitergeben
an andere braucht die App eine Developer-ID-Signatur und eine Beglaubigung (Notarisierung) durch Apple.

## Bauen und starten

Voraussetzung sind macOS 14 oder neuer und die Command Line Tools (`xcode-select --install`); Xcode ist nicht nötig.

```bash
./build.sh
```

```bash
open build/Speicher-Explorer.app
```

Mit `./build.sh --install` landet die App zusätzlich in `~/Applications`. Das Skript baut, prüft Kontraste und Texte,
zeichnet das App-Symbol, packt alles in ein `.app`-Paket und signiert es.

## Prüfungen

- `--check-contrast`: alle Textfarben gegen helle und dunkle Systemflächen, mindestens 4,5:1.
- `--check-strings`: jeder Text existiert in jeder Sprache, mit denselben Platzhaltern (läuft im fertigen Paket).
- `--selftest`: misst Benutzerordner, Programme und den temporären Bereich, vergleicht mit `du` (höchstens 2 %
  Abweichung) und prüft Kategorien, Suche und große Dateien; gibt nur Zahlen aus, keine Namen.

```bash
swift build -c release && .build/release/SpeicherExplorer --selftest
```

Zum Ausprobieren: `open build/Speicher-Explorer.app --args -pane copies` öffnet gleich einen Bereich (`overview`,
`explorer`, `largeFiles`, `temp`, `copies`), `-openSettings YES` die Einstellungen und `-language en` eine Sprache.

## Aufbau

Jede Datei hat eine Aufgabe und bleibt kurz. Seiten bauen ihre Oberfläche nur aus der Factory `UI`, Texte kommen nur
aus `Loc`, Zahlen und Symbolnamen nur aus den Konstanten.

| Ordner | Inhalt |
| --- | --- |
| `Sources/App` | Einstieg, Fenster, Befehle, Übernahme von Sprache und Erscheinungsbild |
| `Sources/Core` | Konstanten (`ScanConfig`, `Layout`, `Symbols`), Pfade, Einstellungen, Enums wie `Pane` und `TempPart` |
| `Sources/Localization` | `Loc` (jeder Text als Schlüssel) und der `Localizer` mit Sprachwahl |
| `Sources/Models` | Ordner-Baum (`Node`), Tabellenzeilen (`Entry`), Datenträger, Kategorien, Prüfkopien |
| `Sources/Services` | Messen (fts), Datenträger, Kategorien, Prüfkopien, Suche, Berechtigungen, Finder, Formate |
| `Sources/State` | `AppModel`: Auswahl, Baum und alles, was daraus abgeleitet wird |
| `Sources/DesignSystem` | Factory `UI`, Bausteine (Karte, Zeilen, Hinweise, Speicherbalken), Liquid Glass, Farben, Symbol |
| `Sources/Features` | je Seite ein Ordner: Überblick, Ordner, Große Dateien, Suche, Temporär, Prüfkopien, Datenträger, Einstellungen |
| `Sources/Diagnostics` | Kontrast- und Textprüfung, Selbsttest |
| `Resources` | `de.lproj` und `en.lproj` mit allen Texten |

Eine neue Sprache braucht einen Ordner `Resources/<code>.lproj` und einen Eintrag in `AppLanguage`; eine neue Seite
einen Fall in `Pane`, dann erscheint sie in der Seitenleiste von selbst.

## Energie

- Ein Durchgang mit `fts(3)` in der App statt vieler `du`-Prozesse; danach kosten Klicks, Sortieren und Suche keine
  neue Messung.
- Standardmäßig Hintergrund-Priorität, auf Apple Silicon also die Effizienzkerne; im Stromsparmodus keine
  automatische Messung.
- Nach der Messung 0 % CPU: keine Timer, keine Dauer-Animationen, keine Abfragen im Hintergrund. Die Suche wartet,
  bis das Tippen pausiert. Liquid Glass lässt sich ausschalten, das spart etwas Grafikleistung.
