import AppKit
import SwiftUI

// MARK: Überblick

struct OverviewScreen: View {
    @Environment(AppState.self) private var app
    @State private var sizes: [URL: Int64] = [:]
    @State private var snapshots: Int?
    @State private var volume = Disk.volume()
    private let areas = Disk.overviewAreas

    var body: some View {
        Screen {
            Header(art: Art.drive, title: "Überblick", subtitle: "Die großen Bereiche deines Macs") {
                DiskLine()
                Text("Time-Machine-Schnappschüsse: \(snapshots.map(String.init) ?? "…")").foregroundStyle(.muted)
            }
            Card(title: "Belegung") {
                HStack(spacing: 32) {
                    UsageRing(fraction: volume.fraction).frame(width: 150, height: 150)
                    VStack(spacing: 10) {
                        legend(.usedRing, "belegt", volume.used)
                        legend(.freeRing, "frei", volume.free)
                    }
                    .frame(maxWidth: 260)
                }
            }
            Card(title: "Bereiche") {
                    ForEach(areas, id: \.self) { url in
                        RowButton { app.explore(url) } label: {
                            SizeRow(bytes: sizes[url], total: sizes.values.max() ?? 1,
                                    label: url == Disk.tempArea ? "Temporärer Systembereich" : Disk.display(url), symbol: "folder")
                        }
                        .help("Im Ordner-Explorer öffnen")
                    }
                    if sizes.count < areas.count { Loading(text: "Messe die Bereiche, das dauert einen Moment …").padding(.top, 6) }
                    else { Button("Neu messen") { Task { await measure() } }.padding(.top, 6) }
            }
            Text("Größen zählen APFS-Klone voll mit; Kopien, die sich Speicherblöcke teilen, belegen real weniger.")
                .foregroundStyle(.muted)
        }
        .task { await measure() }
    }

    private func legend(_ color: Color, _ label: String, _ bytes: Int64) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label)
            Spacer()
            Text(Disk.bytes(bytes)).bold().monospacedDigit()
        }
    }

    private func measure() async {
        sizes = [:]
        volume = Disk.volume()
        async let snaps = Disk.snapshotCount()
        await withTaskGroup(of: (URL, Int64).self) { group in
            for url in areas { group.addTask { (url, await Disk.size(url)) } }
            for await (url, bytes) in group { sizes[url] = bytes }
        }
        snapshots = await snaps
    }
}

struct UsageRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(.freeRing, lineWidth: 22)
            Circle().trim(from: 0, to: fraction).stroke(.usedRing, lineWidth: 22).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((fraction * 100).rounded())) %").font(.title.bold()).monospacedDigit()
                Text("belegt").foregroundStyle(.muted)
            }
        }
        .padding(11)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Temporärer Bereich

struct TempScreen: View {
    @Environment(AppState.self) private var app
    @State private var parts: [Entry]?
    @State private var xItems: [Entry]?
    private static let names = ["T": "temporäre Dateien", "C": "Caches", "X": "Prüfkopien von Apps", "0": "Systemdienste"]

    var body: some View {
        Screen {
            Header(art: Art.hourglass, title: "Temporärer Systembereich", subtitle: Disk.tempArea.path) {
                Text("\(Text("T").bold()) temporäre Dateien · \(Text("C").bold()) Caches · \(Text("X").bold()) Prüfkopien von Apps · \(Text("0").bold()) Systemdienste")
            }
            Card(title: "Die vier Unterordner") {
                if let parts {
                    ForEach(parts) { e in
                        RowButton { app.explore(e.url) } label: {
                            SizeRow(bytes: e.bytes, total: parts.map(\.bytes).max() ?? 1,
                                    label: "\(e.url.lastPathComponent)  ·  \(Self.names[e.url.lastPathComponent] ?? "")", symbol: "folder")
                        }
                    }
                } else { Loading(text: "Messe …") }
            }
            Card(title: "Inhalt von X: je Ordner eine App") {
                if let xItems {
                    if xItems.isEmpty { Text("(leer oder kein Zugriff)").foregroundStyle(.muted) }
                    ForEach(xItems) { e in
                        RowButton { e.url == Disk.chromeClones ? (app.area = .chrome) : app.explore(e.url) } label: {
                            SizeRow(bytes: e.bytes, total: xItems.first?.bytes ?? 1, label: e.url.lastPathComponent, symbol: e.symbol)
                        }
                    }
                } else { Loading(text: "Messe …") }
            }
            HStack {
                Button("Erkunden") { app.explore(Disk.tempArea) }
                Button("Chrome-Prüfkopien") { app.area = .chrome }
                Button("Neu messen") { Task { await load() } }.disabled(parts == nil || xItems == nil)
            }
        }
        .task { await load() }
    }

    private func load() async {
        parts = nil
        xItems = nil
        let urls = ["T", "C", "X", "0"].map { Disk.tempArea.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        async let x = Disk.children(Disk.tempArea.appendingPathComponent("X"))
        var measured: [URL: Int64] = [:]
        await withTaskGroup(of: (URL, Int64).self) { group in
            for url in urls { group.addTask { (url, await Disk.size(url)) } }
            for await (url, bytes) in group { measured[url] = bytes }
        }
        parts = urls.map { Entry(url: $0, bytes: measured[$0] ?? 0) }
        xItems = await x.items
    }
}

// MARK: Chrome-Prüfkopien

struct ChromeScreen: View {
    @Environment(AppState.self) private var app
    @State private var info: Disk.ChromeInfo?
    @State private var loaded = false
    @State private var running = Disk.chromeRunning
    @State private var confirming = false
    @State private var deleting = false
    @State private var freed: Int64?
    @State private var error: String?

    var body: some View {
        Screen {
            Header(art: Art.chrome, title: "Chrome-Prüfkopien", subtitle: "Kopien, die macOS beim Prüfen der Signatur von Chrome anlegt") {
                DiskLine().id(freed)
                if let info {
                    Text("\(Text("\(info.count)").bold()) Kopien · \(Text("\(info.apps)").bold()) mit kompletter Chrome-App · gezählt \(Text(Disk.bytes(info.bytes)).bold())")
                }
                HStack(spacing: 14) {
                    if loaded { Text("installiert: \(Text(info?.installed ?? Disk.version(of: URL(fileURLWithPath: "/Applications/Google Chrome.app")) ?? "nicht gefunden").bold())") }
                    Label(running ? "Chrome läuft" : "Chrome ist beendet", systemImage: "circle.fill")
                        .foregroundStyle(running ? .warn : .good)
                }
            }
            if let freed {
                Card { Label("Aufgeräumt. Wirklich frei geworden: \(Disk.bytes(freed))", systemImage: "checkmark.circle.fill").foregroundStyle(.good).font(.headline) }
            }
            if let error {
                Card { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.bad) }
            }
            if !loaded || deleting {
                Loading(text: deleting ? "Lösche die Kopien …" : "Zähle und messe die Kopien …")
            } else if let info {
                HStack(alignment: .top, spacing: 18) {
                    Card(title: "Kopien nach Chrome-Version") {
                        ForEach(info.versions, id: \.version) { v in
                            HStack(spacing: 10) {
                                Text("\(v.count)").bold().monospacedDigit().frame(width: 44, alignment: .trailing)
                                Text("Kopien  \(v.version)")
                                Spacer()
                                Text(v.version == info.installed ? "aktuelle Version" : "alte Version")
                                    .foregroundStyle(v.version == info.installed ? .good : .warn)
                            }
                        }
                    }
                    Card(title: "Kopien nach Datum") {
                        ForEach(info.days, id: \.day) { d in
                            HStack(spacing: 10) {
                                Text("\(d.count)").bold().monospacedDigit().frame(width: 44, alignment: .trailing)
                                Text("Kopien vom \(d.day)")
                            }
                        }
                    }
                }
                Text("Das sind keine eigenen Programme. macOS legt bei Bedarf eine neue Kopie an, deshalb ist Löschen unbedenklich, solange Chrome beendet ist.")
                    .foregroundStyle(.muted)
                HStack(spacing: 12) {
                    Button("Alle \(info.count) Kopien löschen …", role: .destructive) { confirming = true }
                        .buttonStyle(.borderedProminent).tint(Color.danger)
                        .disabled(running || info.count == 0)
                    Button("Im Ordner erkunden") { app.explore(Disk.chromeClones) }
                    Button("Neu messen") { Task { await load() } }
                }
                if running {
                    Text("Chrome läuft noch. Beende Chrome komplett mit ⌘Q, dann lässt sich löschen.").foregroundStyle(.warn)
                }
            } else {
                Card { Text("Keine Chrome-Prüfkopien vorhanden.") }
                Button("Neu messen") { Task { await load() } }
            }
        }
        .task { await load() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in running = Disk.chromeRunning }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in running = Disk.chromeRunning }
        .confirmationDialog("Alle \(info?.count ?? 0) Chrome-Prüfkopien löschen?", isPresented: $confirming) {
            Button("\(info?.count ?? 0) Kopien endgültig löschen", role: .destructive) { Task { await delete() } }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Kopien landen nicht im Papierkorb. macOS legt beim nächsten Chrome-Start bei Bedarf eine neue an.")
        }
    }

    private func load() async {
        loaded = false
        info = await Disk.chromeInfo()
        running = Disk.chromeRunning
        loaded = true
    }

    private func delete() async {
        running = Disk.chromeRunning  // checked again at the last moment
        guard !running else { return }
        deleting = true
        error = nil
        do { freed = try await Disk.deleteChromeClones() } catch { self.error = "Nicht alles ließ sich löschen: \(error.localizedDescription)" }
        deleting = false
        await load()
    }
}

// MARK: Ordner erkunden

struct ExplorerScreen: View {
    @Environment(AppState.self) private var app
    @State private var total: Int64?
    @State private var items: [Entry]?
    @State private var path = ""
    @State private var pathError = false
    @State private var sheet: Entry?

    var body: some View {
        let dir = app.explorerDir
        Screen {
            Header(art: Art.forPath(dir), title: "Ordner erkunden", subtitle: Disk.display(dir)) {
                DiskLine()
                Text("dieser Ordner: \(Text(total.map(Disk.bytes) ?? "…").bold())").foregroundStyle(.muted)
            }
            HStack(spacing: 10) {
                Button("Zurück", systemImage: "chevron.left") { app.explorerDir = dir.deletingLastPathComponent() }
                    .disabled(dir.path == "/")
                Button("Benutzerordner", systemImage: "house") { app.explorerDir = Disk.home }
                Button("Details", systemImage: "info.circle") { sheet = Entry(url: dir, bytes: total ?? 0) }
                Button("Im Finder öffnen", systemImage: "folder") { NSWorkspace.shared.open(dir) }
                TextField("Pfad eingeben, z. B. ~/Library", text: $path).onSubmit(go).frame(minWidth: 180)
            }
            if pathError { Text("Das ist kein Ordner.").foregroundStyle(.bad) }
            Card {
                if let items {
                    if items.isEmpty { Text("(leer oder kein Zugriff)").foregroundStyle(.muted) }
                    ForEach(items) { e in
                        RowButton { e.isFolder ? (app.explorerDir = e.url) : (sheet = e) } label: {
                            SizeRow(bytes: e.bytes, total: items.first?.bytes ?? 1, label: e.url.lastPathComponent, symbol: e.symbol)
                        }
                        .contextMenu {
                            Button("Im Finder zeigen") { revealInFinder(e.url) }
                            Button("Details") { sheet = e }
                        }
                    }
                } else { Loading(text: "Messe den Inhalt …") }
            }
        }
        .task(id: dir) {
            items = nil
            total = nil
            let r = await Disk.children(dir)
            total = r.total
            items = r.items
        }
        .sheet(item: $sheet) { DetailSheet(entry: $0) }
    }

    private func go() {
        let p = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        pathError = !(FileManager.default.fileExists(atPath: p, isDirectory: &isDir) && isDir.boolValue)
        if !pathError { app.explorerDir = Disk.real(p) }
    }
}

struct DetailSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @State private var details: Disk.FolderDetails?

    var body: some View {
        let values = try? entry.url.resourceValues(forKeys: [.contentModificationDateKey, .localizedTypeDescriptionKey])
        VStack(alignment: .leading, spacing: 16) {
            Header(art: Art.forPath(entry.url), title: entry.isFolder ? "Details" : entry.url.lastPathComponent, subtitle: Disk.display(entry.url)) {
                if entry.isFolder {
                    if let d = details {
                        Text("\(Text("\(d.files)").bold()) Dateien · \(Text("\(d.dirs)").bold()) Ordner · \(Text("\(d.apps)").bold()) App-Pakete")
                        Text("geändert zwischen \(day(d.oldest)) und \(day(d.newest))").foregroundStyle(.muted)
                    }
                } else {
                    Text("\(Text(Disk.bytes(entry.bytes)).bold()) · geändert \(values?.contentModificationDate?.formatted(date: .numeric, time: .shortened) ?? "?")")
                    Text(values?.localizedTypeDescription ?? "").foregroundStyle(.muted)
                }
            }
            if entry.isFolder {
                Card(title: "Dateitypen nach Größe") {
                    if let d = details {
                        ForEach(d.types, id: \.ext) { t in
                            SizeRow(bytes: t.bytes, total: d.types.first?.bytes ?? 1, label: "\(t.ext)   (\(t.count) Dateien)")
                        }
                    } else { Loading(text: "Werte die Dateien aus …") }
                }
            }
            HStack {
                Button("Im Finder zeigen") { revealInFinder(entry.url) }
                Spacer()
                Button("Schließen") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
        .foregroundStyle(.fg)
        .background(.bg)
        .task { if entry.isFolder { details = await Disk.details(entry.url) } }
    }

    private func day(_ d: Date?) -> String { d?.formatted(date: .numeric, time: .omitted) ?? "?" }
}

// MARK: Große Dateien

struct BigFilesScreen: View {
    @State private var folder = "~"
    @State private var minMB = 500
    @State private var results: [Entry]?
    @State private var searching = false
    @State private var searched = ""

    var body: some View {
        Screen {
            Header(art: Art.magnifier, title: "Große Dateien", subtitle: "Suche nach einzelnen großen Dateien") { DiskLine() }
            Card {
                HStack(spacing: 10) {
                    Text("Ordner")
                    TextField("~", text: $folder).onSubmit(start).frame(minWidth: 200)
                    Button("Wählen …", action: choose)
                    Text("ab")
                    TextField("MB", value: $minMB, format: .number).onSubmit(start).frame(width: 70)
                    Text("MB")
                    Button("Suchen", action: start).buttonStyle(.borderedProminent).tint(Color.buttonFill).disabled(searching)
                }
            }
            if searching { Loading(text: "Suche …") }
            if let results, !searching {
                Card(title: "\(results.count) Treffer \(searched)") {
                    let top = results.first?.bytes ?? 1
                    ForEach(results) { e in
                        RowButton { revealInFinder(e.url) } label: {
                            SizeRow(bytes: e.bytes, total: top, label: Disk.display(e.url), symbol: e.symbol)
                        }
                        .help("Im Finder zeigen")
                    }
                }
                Text("Platten von virtuellen Maschinen (z. B. Docker.raw) zeigen ihre Maximalgröße, belegen real oft viel weniger.")
                    .foregroundStyle(.muted)
            }
        }
    }

    private func start() {
        guard !searching else { return }
        let dir = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath)
        let mb = max(1, minMB)
        searched = "ab \(mb) MB in \(Disk.display(dir))"
        searching = true
        Task {
            results = await Disk.bigFiles(in: dir, minMB: mb)
            searching = false
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { folder = Disk.display(url) }
    }
}
