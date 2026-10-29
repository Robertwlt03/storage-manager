<p align="center">
  <img src="assets/banner-architektur.svg" alt="Architektur des Speicher-Explorers. Wo im Code was liegt und warum." width="100%">
</p>

Diese Beschreibung hilft dir herauszufinden, wo eine Änderung hingehört. Sie nennt Dateien und Typen beim Namen,
damit du sie mit der Suche deines Editors findest. Wie du baust und prüfst, steht in der
[Anleitung zum Mitmachen](CONTRIBUTING.md).

## <img src="assets/icons/about.svg" height="33" align="absmiddle" alt="">Worum es geht

Der Speicher-Explorer misst einmal, wie viel Platz die Ordner des Macs belegen, und zeigt das Ergebnis auf mehreren
Seiten: als Überblick, als Ordnerbaum, als Liste großer Dateien, beim Aufräumen und in versteckten Bereichen wie dem
temporären Ordner von macOS. Nach der Messung kommt jede Seite ohne weiteren Festplattenzugriff aus.

## <img src="assets/icons/dataflow.svg" height="33" align="absmiddle" alt="">Der Weg der Daten

1. `ScanService` läuft mit `FileTreeWalker` einmal über einen Bereich der Festplatte, auf den sparsamen Kernen des Prozessors.
2. Daraus entsteht ein Baum aus `Node`. Ordner und Dateien unter einem Megabyte fasst jeder Ordner zu einer Zeile
   zusammen. Das hält den Baum klein.
3. `AppModel` hält diesen Baum und alles, was daraus folgt: Kategorien, Kennzahlen, Aufräum-Vorschläge und Apps. Es
   erhöht `revision`, sobald sich der Baum ändert.
4. Die Seiten lesen nur aus `AppModel` und rechnen mit den Services. Selbst greifen sie nie auf die Festplatte zu.

## <img src="assets/icons/codemap.svg" height="33" align="absmiddle" alt="">Code-Karte

**`Sources/App`:** Der Start der App mit Fenster, Menüs und `RootView`. `RootView` hält die Seitenleiste, die Suche und
die gerade gewählte Seite zusammen.

**`Sources/Core`:** Feste Werte und Auswahlen ohne Oberfläche. `Pane` beschreibt jede Seite in der Tabelle `details`.
`Settings` enthält die gespeicherten Einstellungen und die Sprachwahl, `Paths` die Orte auf der Festplatte und
`Constants` die einstellbaren Zahlen der Messung.

**`Sources/Models`:** Die Daten: `Node` als Ordnerbaum, `Entry` für eine Zeile in Tabellen, dazu Kategorien,
Aufräum-Arten und App-Nutzung.

**`Sources/Services`:** Die eigentliche Arbeit, jeweils ohne Oberfläche. Dazu gehören Messen, Kategorien, Suche,
Aufräumen, App-Kopien, Kennzahlen, Zusammenfassung, Vorlesen, Vorschaubilder und alles, was mit dem Finder oder den
Systemeinstellungen spricht.

**`Sources/State`:** `AppModel`, das die Services zusammenführt und den Zustand der Oberfläche hält.

**`Sources/DesignSystem`:** Alle Bausteine im Namensraum `UI` mit ihren Varianten. `Tokens` enthält Abstände,
Icon-Größen, Textrollen, Maße und Symbolnamen, `Theme` die Farben, `Surface` Karten und Knopfarten und `Motion` alle
Animationen.

**`Sources/Features`:** Jede Seite in einem eigenen Ordner. `Pages.swift` ordnet jeder Seite ihre Ansicht zu.
`Shared` enthält die gemeinsame Tabelle und das gemeinsame Raster für Ordner, Suchergebnisse und große Dateien.

**`Sources/Localization` und `Resources`:** `TextKey` enthält alle englischen Textschlüssel, die 20 Sprachordner enthalten die Texte.

**`Sources/Diagnostics`:** Der Selbsttest mit echten Ordnern und der Belastungstest, der die laufende App bedient.

**`Tests/SpeicherExplorerTests`:** Die Tests mit Swift Testing für Ordnerbaum, Suche, Seiten, Gestaltungswerte, Kontrast
und Übersetzungen. Sie bauen ihre Ordnerbäume von Hand und greifen nie auf die Festplatte zu.

## <img src="assets/icons/rules.svg" height="33" align="absmiddle" alt="">Absichtliche Regeln

Diese Regeln sieht man dem Code nicht an. Bitte brich sie nur, wenn du den Grund kennst und ihn hier anpasst.

**Datenschutz:** Kein Programmteil gibt Datei- oder Ordnernamen aus. Die App sendet nichts ins Netz.

**Löschen:** Löschen geschieht nur nach einer Bestätigung. Kopien einer App werden nur gelöscht, wenn sie nicht läuft,
und das wird direkt vor dem Löschen noch einmal geprüft.

**Eine Messung, keine zweite:** Alles, was die Seiten zeigen, kommt aus dem Baum der letzten Messung. Ein zweiter Lauf
über die Festplatte, etwa für das Aufräumen, kostete früher spürbar Energie. Nur das Info-Fenster eines Ordners
analysiert auf Wunsch noch einmal genauer.

**Diagramme ohne Animation:** Swift Charts stürzte ab, wenn ein Diagramm während einer Messung zwischen wechselnden
Daten animierte. Diagramme zeichnen deshalb ohne Animation neu (`staticChart`) und warten, bis die Messung fertig ist.

**Tabellen werden neu gebaut, nicht verglichen:** Wenn sich der ganze Inhalt einer Tabelle ändert, etwa bei einem
anderen Ordner oder einer neuen Suche, baut `contentKey` die Tabelle neu. Das Vergleichen tausender neuer Zeilen löste
in AppKit Fehler aus, weil die Tabelle sich währenddessen selbst aktualisieren wollte. Aus demselben Grund gibt es
keine anpassbaren Spalten, und Tabellen ändern sich nie innerhalb einer Animation.

**Start ohne Animation:** Die Messung beim Start beginnt, bevor das Fenster zum ersten Mal gezeichnet ist. Wäre dieser
Moment animiert, würden alle Karten aus der linken oberen Ecke wachsen. Deshalb sind Beginn und Ende einer Messung
nicht animiert.

**Seitenleiste:** Den Knopf und den Menübefehl des Systems ersetzt die App durch eigene, denn beim Einblenden über
AppKit sprang die Seite ohne Zwischenbilder auf ihre neue Breite. SwiftUI animiert sie stattdessen gleichmäßig. Der
Knopf zeichnet seinen Glaskreis selbst, damit macOS beim Platzwechsel keinen leeren Kreis zurücklässt. Bei jeder
Größenänderung des Fensters vergleicht `SidebarState`, ob die Seitenleiste offen sein sollte, denn an der Grenze schließt
macOS sie manchmal selbst. Die Breite liest `AppModel` dafür direkt vom Fenster, weil die Breite aus SwiftUI während der
Bewegung kurz über die Grenze springt.

**Schwebende Seitenleiste:** In schmalen Fenstern schwebt die Seitenleiste über der Seite. Sie wird nur hinein- und
hinausgeschoben, nie entfernt, weil die Liste darin sonst abrupt verschwindet. Sie wird auch nicht ausgeblendet, damit
der Glaseffekt erhalten bleibt.

**Laden:** Werte, die noch berechnet werden, behalten ihren Platz und zeigen ein kleines Ladesymbol (`calculating`).
Knöpfe, die sich auf diese Werte beziehen, warten, bis sie feststehen. Wo mehr Platz ist, zeigt `UI.Placeholder`, was
gerade geladen wird.

**Hauptthread als Standard:** Der Code ist in Swift 6 geschrieben, und alles läuft auf dem Hauptthread, solange es
nichts anderes sagt. Nur was wirklich im Hintergrund arbeitet, also Messen, Aufräumen, die Analyse im Info-Fenster und
die App-Kopien, ist mit `nonisolated` markiert. Der Compiler prüft dann, dass keine Daten gleichzeitig von zwei Stellen
verändert werden. Den Ordnerbaum baut eine Messung im Hintergrund und übergibt ihn danach als Ganzes, deshalb darf
`Node` die Seite wechseln.

**Selbsttest und Belastungstest nur mit Vollzugriff:** Beide messen echte Ordner. Ohne Festplattenvollzugriff würde
macOS dabei für jeden geschützten Ordner und für die Daten jeder anderen App einzeln fragen, oft hunderte Male. Deshalb
prüfen beide zuerst den Vollzugriff und hören ohne ihn sofort auf, und `make selftest` startet die gebaute App statt
des nackten Programms, damit macOS den Vollzugriff der App anrechnet.

**Vorführmodus:** Mit `-demo YES` füllt sich die App mit den erfundenen Daten aus `DemoData` statt zu messen. `AppModel`
sperrt dann jeden Zugriff auf die Festplatte und jedes Entfernen, und auch das Info-Fenster analysiert nichts. Die Pfade
der erfundenen Dateien und Aufräum-Einträge gibt es nicht, ein Test prüft das.

**Energie:** Keine Animation läuft im Ruhezustand. Die Messung läuft mit niedriger Priorität, und der Fortschritt
meldet sich höchstens zweimal pro Sekunde.

**Sprache und Aussehen:** Sprache, Erscheinungsbild und Einheiten kommen aus den Systemeinstellungen. Die App hat dafür
keine eigenen Schalter.

**Kontrast:** Jede Textfarbe erreicht in beiden Erscheinungsbildern mindestens 4,5 zu 1. Deshalb nutzt Text für
Nebensächliches den Ton `muted` statt der Systemfarbe, die im hellen Modus darunter bleibt.

<p align="center">
  <img src="assets/banner-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · Sieh auf einen Blick, wo dein Speicher steckt.</b><br>
  <sub><a href="README.md">Übersicht</a> · <a href="CONTRIBUTING.md">Mitmachen</a> · <a href="ARCHITECTURE.md">Architektur</a> · <a href="CODE_STYLE.md">Code-Regeln</a> · <a href="CODE_OF_CONDUCT.md">Verhaltensregeln</a></sub><br>
  <sub>© 2026 Robertwlt03 · Veröffentlicht unter der <a href="LICENSE">MIT-Lizenz</a> · Für macOS 27 auf Macs mit Apple-Chip</sub>
</p>
