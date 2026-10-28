# Speicher-Explorer

Eine kleine macOS-App, die zeigt, wo auf dem Mac der Speicherplatz steckt. Sie ist aus dem Terminal-Skript
`speicher_explorer.sh` entstanden und übernimmt dessen Bereiche und Pixel-Symbole, jetzt als native SwiftUI-App.
Die App schickt nichts weg und löscht nur an einer Stelle, nämlich die Chrome-Prüfkopien, und das nur nach einer
ausdrücklichen Bestätigung.

## Bereiche

- **Überblick**: Belegungsring der Festplatte, freie und belegte Größe, Zahl der Time-Machine-Schnappschüsse und die
  großen Bereiche (Benutzerordner, Library, Programme, temporärer Systembereich …) mit Größenbalken. Ein Klick öffnet
  den Bereich im Ordner-Explorer.
- **Temporärer Bereich**: der persönliche Bereich unter `/private/var/folders/…` mit den Unterordnern T (temporäre
  Dateien), C (Caches), X (Prüfkopien von Apps) und 0 (Systemdienste) sowie dem Inhalt von X.
- **Chrome-Prüfkopien**: Kopien, die macOS beim Prüfen der Chrome-Signatur unter
  `…/X/com.google.Chrome.code_sign_clone` anlegt. Die App zeigt Anzahl, Versionen im Vergleich zur installierten
  Chrome-Version und die Tage, an denen die Kopien entstanden sind. Löschen geht nur, solange Chrome beendet ist, und
  nur nach Bestätigung; danach zeigt die App, wie viel Platz wirklich frei geworden ist.
- **Ordner erkunden**: Inhalt eines Ordners nach Größe sortiert. Ein Klick auf einen Ordner geht tiefer, „Zurück“ geht
  eine Ebene hoch, „Details“ zählt Dateien, Ordner und App-Pakete und listet die Dateitypen nach Größe, das
  Kontextmenü zeigt einen Eintrag im Finder.
- **Große Dateien**: sucht einzelne Dateien ab einer Mindestgröße (Standard 500 MB) in einem Ordner.

Alle Größen zählen APFS-Klone voll mit, so wie `du`. Kopien, die sich Speicherblöcke teilen, belegen real weniger;
deshalb misst die App nach dem Löschen den tatsächlich frei gewordenen Platz.

## Bauen und starten

Voraussetzung sind macOS 14 oder neuer und die Command Line Tools (`xcode-select --install`); Xcode ist nicht nötig.

```bash
./build.sh
open build/Speicher-Explorer.app
```

Mit `./build.sh --install` landet die App zusätzlich in `~/Applications`, danach lässt sie sich wie jede andere App
über Launchpad, Spotlight oder den Finder öffnen und im Dock behalten.

Das Skript baut mit `swift build -c release`, prüft die Textkontraste, packt das Programm in ein `.app`-Paket mit
Symbol und signiert es ad hoc für diesen Mac.

### Zugriffsrechte

Beim ersten Messen fragt macOS eventuell, ob die App auf Schreibtisch, Dokumente oder Downloads zugreifen darf. Für
vollständige Zahlen (zum Beispiel in `~/Library/Containers`) kann die App unter Systemeinstellungen → Datenschutz &
Sicherheit → Festplattenvollzugriff freigegeben werden. Weil jeder Neubau ad hoc neu signiert wird, kann macOS nach
einem Neubau erneut fragen.

## Prüfungen

```bash
swift build && .build/debug/SpeicherExplorer --check-contrast
```

prüft alle Text- und Hintergrundfarben in hellem und dunklem Modus auf mindestens 4,5:1 (WCAG AA); `build.sh` bricht
ab, wenn ein Paar darunter liegt.

```bash
.build/debug/SpeicherExplorer --selftest
```

rechnet alle Bereiche auf den echten Daten dieses Macs durch und gibt dabei nur Anzahlen und Größen aus, keine Datei-
oder Ordnernamen.

Zum Ausprobieren lässt sich die App direkt in einem Bereich öffnen, zum Beispiel
`open build/Speicher-Explorer.app --args -area chrome` (Werte: `overview`, `temp`, `chrome`, `explorer`, `bigFiles`).

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `Sources/App.swift` | Einstieg, Kommandozeilen-Schalter, Seitenleiste und Bereichswechsel |
| `Sources/Screens.swift` | die fünf Bereiche und das Detailfenster |
| `Sources/Components.swift` | Pixel-Symbole, Größenbalken, Kopfzeile, Karten |
| `Sources/Disk.swift` | Messen (`du`, `find`, `FileManager`), Chrome-Kopien, Selbsttest |
| `Sources/Theme.swift` | Farben für hell und dunkel und die Kontrastprüfung |

## Windows

Die App ist bewusst nur für macOS gebaut. Für Windows müsste die Oberfläche neu entstehen (zum Beispiel mit WinUI
oder einer plattformübergreifenden Lösung); die macOS-spezifischen Teile wie `/private/var/folders` und die
Chrome-Prüfkopien gibt es dort nicht, die übrigen Bereiche lassen sich übertragen.
