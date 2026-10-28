# Speicher-Explorer

Eine native macOS-App, die zeigt, wo auf dem Mac der Speicherplatz steckt. Sie misst alle wichtigen Bereiche in einem
einzigen, energiesparenden Durchgang, ordnet den belegten Platz in Kategorien wie in den Systemeinstellungen unter
„Speicher“ und lässt dich danach ohne erneutes Messen durch alle Ordner klicken. Die App schickt nichts weg und löscht
nur an einer Stelle, nämlich bei den Prüfkopien, und das erst nach einer ausdrücklichen Bestätigung.

## Bereiche

- **Überblick**: der Startdatenträger mit einem gestapelten Balken wie in den Systemeinstellungen und die Kategorien
  nach Größe sortiert (Programme, Dokumente, Downloads, App-Daten, Caches, Entwicklung, Papierkorb, temporäre Dateien,
  von macOS löschbarer Platz, System & Sonstiges …). Die Kategorien entstehen aus Regeln für bekannte Ordner; was auf
  einem Mac nicht existiert, bleibt einfach weg. Ein Klick öffnet die Kategorie im Ordner-Explorer.
- **Ordner**: eine native Tabelle mit Finder-Symbolen, sortierbar nach Name, Größe, Anteil und Dateizahl. Doppelklick
  geht tiefer, die Zurück-Taste in der Symbolleiste wieder hoch. Das Kontextmenü zeigt „Im Finder zeigen“,
  „Informationen“ (Dateitypen, Anzahl, Zeitraum) und „Pfad kopieren“. Spalten lassen sich über den Tabellenkopf
  ein- und ausblenden.
- **Große Dateien**: alle Dateien ab einer wählbaren Größe (10 MB bis 5 GB), sofort aus der letzten Messung.
- **Temporärer Bereich**: der versteckte Bereich unter `/private/var/folders/…` mit T, C, X und 0.
- **Prüfkopien**: Kopien, die macOS beim Prüfen von App-Signaturen im Ordner X anlegt, für jede App getrennt (zum
  Beispiel Chrome). Die App zeigt Anzahl, Versionen im Vergleich zur installierten Version und die Tage, an denen die
  Kopien entstanden sind. Löschen geht nur, solange die App beendet ist, und nur nach Bestätigung; danach zeigt sie,
  wie viel Platz wirklich frei geworden ist.
- **Datenträger**: jeder angeschlossene Datenträger mit Kapazität, belegtem, löschbarem und freiem Platz. Externe
  Datenträger lassen sich mit einem Klick zusätzlich messen.

Gemessen wird der belegte Platz wie mit `du` (der Selbsttest vergleicht beides). APFS-Klone zählen dabei voll mit;
Kopien mit gemeinsamen Speicherblöcken belegen real weniger.

## Energie

- Ein einziger Durchgang mit `fts(3)` direkt in der App statt vieler `du`-Prozesse; das Ergebnis bleibt als Baum im
  Speicher, deshalb kosten Klicks, Sortieren und die Suche nach großen Dateien keine neue Messung.
- Standardmäßig misst die App mit Hintergrund-Priorität; auf Apple Silicon läuft das auf den Effizienzkernen.
- Im Stromsparmodus misst sie nicht automatisch.
- Nach der Messung liegt die App bei 0 % CPU: keine Timer, keine Dauer-Animationen, keine Abfragen im Hintergrund.
  Datenträger werden nur neu gelesen, wenn macOS das An- oder Abmelden eines Datenträgers meldet.
- Ordner und Dateien unter 1 MB fasst die App pro Ordner zu einer Zeile zusammen; so bleibt der Baum klein
  (rund 110 MB Arbeitsspeicher für eine Million Dateien).

## Einstellungen (⌘,)

- **Darstellung**: Erscheinungsbild (System, Hell, Dunkel), Diagrammfarben (bunt, Akzentfarbe, Grautöne) und binäre
  Einheiten statt der Finder-Einheiten.
- **Messen**: beim Start automatisch messen, im Stromsparmodus pausieren, energiesparend messen und zusätzliche Ordner,
  die mitgemessen werden.

## Bauen und starten

Voraussetzung sind macOS 14 oder neuer und die Command Line Tools (`xcode-select --install`); Xcode ist nicht nötig.

```bash
./build.sh
open build/Speicher-Explorer.app
```

Mit `./build.sh --install` landet die App zusätzlich in `~/Applications`, danach lässt sie sich wie jede andere App
über Launchpad, Spotlight oder den Finder öffnen und im Dock behalten.

Das Skript baut mit `swift build -c release`, prüft die Textkontraste, zeichnet das App-Symbol, packt alles in ein
`.app`-Paket und signiert es ad hoc für diesen Mac.

### Zugriffsrechte

Geschützte Ordner (zum Beispiel von Mail oder Safari) kann die App erst mit Festplattenvollzugriff messen. Unten in
der Seitenleiste steht dann, wie viele Ordner nicht lesbar waren, mit einem Link zur passenden Systemeinstellung.
Weil jeder Neubau ad hoc neu signiert wird, kann macOS nach einem Neubau erneut fragen.

## Prüfungen

```bash
swift build && .build/debug/SpeicherExplorer --check-contrast
```

prüft die Textfarben gegen helle und dunkle Systemflächen auf mindestens 4,5:1 (WCAG AA); `build.sh` bricht ab, wenn
ein Paar darunter liegt.

```bash
swift build -c release && .build/release/SpeicherExplorer --selftest
```

misst Benutzerordner, Programme und den temporären Bereich, vergleicht jedes Ergebnis mit `du` (höchstens 2 %
Abweichung) und gibt Dateizahl, Größe, Dauer und CPU-Zeit aus, aber keine Datei- oder Ordnernamen.

Zum Ausprobieren lässt sich die App direkt in einem Bereich öffnen, zum Beispiel
`open build/Speicher-Explorer.app --args -pane copies` (Werte: `overview`, `explorer`, `largeFiles`, `temp`, `copies`);
`--args -openSettings YES` öffnet gleich die Einstellungen.

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `Sources/App.swift` | Einstieg, Kommandozeilen-Schalter, Fenster, Seitenleiste, Einstellungen, Selbsttest |
| `Sources/Model.swift` | Messablauf, Datenträger, Kategorien, Prüfkopien |
| `Sources/Scanner.swift` | der fts-Scanner und der Ordner-Baum |
| `Sources/Views.swift` | alle Ansichten und das Informationsfenster |
| `Sources/Theme.swift` | Einstellungsschlüssel, Textfarben mit Kontrastprüfung, Diagrammfarben, App-Symbol |

## Windows

Die App ist bewusst nur für macOS gebaut. Für Windows müsste die Oberfläche neu entstehen; der Scanner-Gedanke (ein
Durchgang, Baum im Speicher) lässt sich übertragen, die macOS-Bereiche wie `/private/var/folders` und die Prüfkopien
gibt es dort nicht.
