# Mitmachen beim Speicher-Explorer

Schön, dass du mithelfen möchtest. Diese Anleitung erklärt, wie du die App baust, wo du was findest und worauf du
achten solltest. Wie der Code aufgebaut ist und welche Regeln absichtlich gelten, steht in der
[Architektur-Beschreibung](ARCHITECTURE.md).

## Was du brauchst

Du brauchst einen Mac mit macOS 14 oder neuer und die Command Line Tools von Apple. Die installierst du mit dem Befehl
unten. Xcode selbst ist nicht nötig.

```bash
xcode-select --install
```

## Die App bauen und starten

Das Skript `build.sh` baut die App, zeichnet das App-Symbol, prüft alle Texte und Farben und legt die fertige App in
den Ordner `build`. Danach startest du sie wie jede andere App.

```bash
./build.sh
```

```bash
open build/Speicher-Explorer.app
```

Ohne weitere Angaben wird die App nur behelfsmäßig signiert. Dann fragt macOS nach jedem Bauen erneut nach dem
Festplattenvollzugriff. Wenn dich das stört, legst du einmalig ein eigenes Zertifikat an und baust mit diesem.

```bash
scripts/create-signing-identity.sh
```

```bash
SIGN_IDENTITY="Speicher-Explorer Dev" ./build.sh
```

## Prüfungen vor jedem Beitrag

`build.sh` bricht ab, sobald eine Prüfung fehlschlägt. Es prüft, ob jeder Text in allen 20 Sprachen vorhanden ist und
gleich viele Platzhalter hat, und ob jede Textfarbe in hellem und dunklem Erscheinungsbild einen Kontrast von
mindestens 4,5 zu 1 erreicht.

Zwei weitere Prüfungen startest du bei Bedarf selbst. Der Selbsttest misst echte Ordner und vergleicht das Ergebnis
mit dem Befehl `du`. Der Belastungstest bedient die laufende App wie ein sehr schneller Mensch und versucht, Fehler
auszulösen. Beide geben nur Anzahlen und Größen aus, niemals Datei- oder Ordnernamen.

```bash
.build/release/SpeicherExplorer --selftest
```

```bash
open -n build/Speicher-Explorer.app --args -uiTest "$TMPDIR/speicher-test"
```

## Regeln, die immer gelten

- **Keine Namen ausgeben:** Ausgaben, Protokolle und Tests zeigen nie Namen von Dateien oder Ordnern, sondern nur
  Anzahlen und Größen. Was auf der Festplatte liegt, ist privat.
- **Nichts löschen ohne Rückfrage:** Die App entfernt nur nach einer Bestätigung etwas, und Kopien einer App nur, wenn
  diese App nicht läuft. Tests löschen nie etwas.
- **Texte in allen Sprachen:** Jeder neue Text bekommt einen Schlüssel in `Loc` und eine Zeile in allen 20 Dateien
  unter `Resources`. Deutsch und Englisch sind die Vorlage. Bei den übrigen Sprachen freuen wir uns besonders über
  Verbesserungen von Muttersprachlern.
- **Code auf Englisch, Dokumentation auf Deutsch:** Namen, Kommentare und Commit-Nachrichten schreibst du auf Englisch,
  Anleitungen wie diese auf Deutsch.
- **Gute Namen statt Kommentare:** Ein Name soll sagen, was etwas tut. Kommentare bleiben für Regeln, die man im Code
  nicht sieht. Geschichten, wie ein Fehler entstanden ist, gehören in die Commit-Nachricht oder in die
  Architektur-Beschreibung.

## Eine neue Seite hinzufügen

1. Lege in `Pane` einen neuen Fall an und gib ihm in der Tabelle `details` seinen Schlüssel, Titel, Info-Text und sein
   Symbol.
2. Schreibe die Seite als eigene Datei in einem neuen Ordner unter `Sources/Features`.
3. Trage sie in `Pane.page` in der Datei `Features/Pages.swift` ein.
4. Lege die neuen Texte in allen Sprachen an.

Die Seitenleiste baut sich aus `Pane` von selbst, dort ist nichts weiter zu tun.

## Bausteine benutzen

Alle Bausteine der Oberfläche liegen im Namensraum `UI`. Wenn du `UI.` tippst, siehst du sie alle. Jeder Baustein hat
wenige feste Varianten, damit gleiche Dinge überall gleich aussehen:

| Baustein | Wofür | Varianten |
| --- | --- | --- |
| `UI.Page` | eine scrollende Seite mit Kopfzeile | mit oder ohne Optionen |
| `UI.Card` | eine abgerundete Fläche | mit oder ohne Überschrift |
| `UI.Rows`, `UI.NavRow`, `UI.Fields` | Zeilen mit Trennlinien | Navigation oder Bezeichnung mit Wert |
| `UI.Icon` | jedes Symbol und Bild | Art und Größe von sehr klein bis groß |
| `UI.Note` | eine Zeile Information | Hinweis, in Arbeit, gut, Warnung, Fehler |
| `UI.Placeholder` | Ersatz für fehlenden Inhalt | leer, lädt, nicht gemessen, auf einer Seite oder Karte |
| `UI.Tile`, `UI.KeyFigure` | Kacheln | Rasterkachel oder Kennzahl |
| `UI.ActionButton` | ein Knopf mit Text | normal, hervorgehoben, bestätigend, still, Inhalt |

Abstände nimmst du aus `Space`, Icon-Größen aus `IconSize` und Schriften über `textRole` aus `TextRole`. Feste Zahlen
oder einzelne Schriften direkt im Code vermeiden wir, denn dann sieht ein Teil der App bald anders aus als der Rest.

## Fehler melden und Ideen vorschlagen

Fehler und Wünsche meldest du über die Issues auf GitHub. Für beides gibt es eine Vorlage, die nach den wichtigsten
Angaben fragt. Bitte füge keine Bildschirmfotos mit privaten Datei- oder Ordnernamen an.

## Umgang miteinander

Wir gehen freundlich und respektvoll miteinander um. Die Einzelheiten stehen in den [Verhaltensregeln](CODE_OF_CONDUCT.md).
