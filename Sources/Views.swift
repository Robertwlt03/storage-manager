import AppKit
import Charts
import SwiftUI

// MARK: Small helpers

func fileIcon(_ path: String) -> Image { Image(nsImage: NSWorkspace.shared.icon(forFile: path)) }
func reveal(_ path: String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }

/// Label and value; the value uses the muted tone because the system's secondary colour is too faint in light mode.
struct Field: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        LabeledContent { Text(value).foregroundStyle(.muted).monospacedDigit().textSelection(.enabled) } label: { Text(label) }
    }
}

struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.callout).foregroundStyle(.muted).fixedSize(horizontal: false, vertical: true) }
}

/// Shown while nothing has been measured yet.
struct NotMeasured: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label(model.scanning ? "Wird gemessen …" : "Noch nicht gemessen", systemImage: "gauge.with.dots.needle.33percent")
        } description: {
            Text(model.scanning ? "Die Ergebnisse erscheinen, sobald der erste Bereich fertig ist." : "Ein Durchgang misst alle Bereiche; danach ist jeder Klick sofort da.")
                .foregroundStyle(.muted)
        } actions: {
            if model.scanning { ProgressView().controlSize(.small) } else { Button("Jetzt messen") { model.scan() }.buttonStyle(.borderedProminent) }
        }
    }
}

// MARK: Overview

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.palette) private var palette = 0

    var body: some View {
        Form {
            if let v = model.startupVolume {
                Section {
                    HStack(spacing: 14) {
                        fileIcon(v.path).resizable().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name).font(.title2.weight(.semibold))
                            Text("\(Fmt.bytes(v.available)) verfügbar von \(Fmt.bytes(v.total))").foregroundStyle(.muted)
                        }
                    }
                    StorageBar(segments: model.categories.map { ($0.title, $0.bytes, Theme.color($0.colorIndex, palette: palette)) },
                               free: v.free, total: v.total)
                }
            }
            Section("Kategorien") {
                if model.categories.isEmpty { NotMeasured().frame(minHeight: 220) }
                ForEach(model.categories) { c in
                    Button { c.node.map(model.open) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Theme.color(c.colorIndex, palette: palette), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(c.title)
                            Spacer()
                            Text(Fmt.bytes(c.bytes)).monospacedDigit().foregroundStyle(.muted)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.muted)
                                .opacity(c.node == nil ? 0 : 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(c.node != nil)  // not .disabled: that would dim the text below 4.5:1
                    .accessibilityLabel("\(c.title), \(Fmt.bytes(c.bytes))")
                }
            }
            if !model.categories.isEmpty {
                Section {
                    Note("Gemessen wird der belegte Platz wie mit „du“. APFS-Klone zählen dabei voll mit, Kopien mit gemeinsamen Speicherblöcken belegen real weniger. „System & Sonstiges“ ist der Rest bis zur Belegung, die macOS meldet.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Überblick")
    }
}

/// Stacked bar like in System Settings › Storage.
struct StorageBar: View {
    let segments: [(title: String, bytes: Int64, color: Color)]
    let free: Int64
    let total: Int64

    var body: some View {
        let items = segments + [("Frei", free, Color.gray.opacity(0.25))]
        Chart(Array(items.enumerated()), id: \.offset) { _, s in
            BarMark(x: .value("Größe", s.bytes), y: .value("Datenträger", "belegt"))
                .foregroundStyle(s.color)
                .accessibilityLabel(s.title)
                .accessibilityValue(Fmt.bytes(s.bytes))
        }
        .chartXScale(domain: 0...max(total, items.reduce(0) { $0 + $1.bytes }))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: Explorer

struct ExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.explorerPath) {
            FolderTable(node: model.root).navigationDestination(for: Node.self) { FolderTable(node: $0) }
        }
    }
}

struct Row: Identifiable {
    enum Kind { case folder(Node), file(String), rest }
    let id: String
    let name: String
    let bytes: Int64
    let items: Int
    let kind: Kind
    var path: String? {
        switch kind {
        case .folder(let n): n.path
        case .file(let p): p
        case .rest: nil
        }
    }
}

struct FolderTable: View {
    let node: Node
    @Environment(AppModel.self) private var model
    @State private var selection: Set<Row.ID> = []
    @State private var sort = [KeyPathComparator(\Row.bytes, order: .reverse)]
    @State private var info: Row?
    @SceneStorage("explorerColumns") private var columns = TableColumnCustomization<Row>()

    private var rows: [Row] {
        _ = model.revision
        let atTop = node.isVirtual
        var r = node.children.map { n in
            Row(id: n.path, name: atTop ? Paths.display(n.name) : n.name, bytes: n.bytes, items: n.fileCount, kind: .folder(n))
        }
        r += node.files.map { Row(id: $0.path, name: $0.name, bytes: $0.bytes, items: 1, kind: .file($0.path)) }
        if node.restCount > 0 {
            r.append(Row(id: "\u{0}rest", name: "\(Fmt.count(node.restCount)) kleinere Objekte unter 1 MB", bytes: node.restBytes,
                         items: node.restCount, kind: .rest))
        }
        return r.sorted(using: sort)
    }

    var body: some View {
        let rows = rows
        let total = max(node.bytes, 1)
        Table(rows, selection: $selection, sortOrder: $sort, columnCustomization: $columns) {
            TableColumn("Name", value: \.name) { r in
                Label {
                    Text(r.name).lineLimit(1).truncationMode(.middle)
                } icon: {
                    if let p = r.path { fileIcon(p).resizable().frame(width: 16, height: 16) } else { Image(systemName: "ellipsis.circle") }
                }
            }
            .customizationID("name")
            TableColumn("Größe", value: \.bytes) { r in
                Text(Fmt.bytes(r.bytes)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
            .customizationID("size")
            TableColumn("Anteil", value: \.bytes) { r in
                HStack(spacing: 8) {
                    ProgressView(value: Double(r.bytes) / Double(total)).progressViewStyle(.linear)
                    Text((Double(r.bytes) / Double(total)).formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit().frame(width: 38, alignment: .trailing)
                }
            }
            .width(min: 90, ideal: 150)
            .customizationID("share")
            TableColumn("Dateien", value: \.items) { r in
                Text(Fmt.count(r.items)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 80, max: 110)
            .customizationID("files")
        }
        .contextMenu(forSelectionType: Row.ID.self) { ids in
            if let r = rows.first(where: { ids.contains($0.id) }), let path = r.path {
                if case .folder(let n) = r.kind { Button("Öffnen") { model.explorerPath.append(n) } }
                Button("Im Finder zeigen") { reveal(path) }
                Button("Informationen") { info = r }
                Divider()
                Button("Pfad kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
            }
        } primaryAction: { ids in
            guard let r = rows.first(where: { ids.contains($0.id) }) else { return }
            switch r.kind {
            case .folder(let n): model.explorerPath.append(n)
            case .file(let p): reveal(p)
            case .rest: break
            }
        }
        .overlay { if node.isVirtual && node.children.isEmpty { NotMeasured() } }
        .navigationTitle(node.isVirtual ? "Ordner" : (node.parent?.isVirtual == true ? Paths.display(node.name) : node.name))
        .navigationSubtitle(node.isVirtual ? "\(Fmt.bytes(node.bytes)) gemessen" : "\(Fmt.bytes(node.bytes)) · \(Paths.display(node.path))")
        .toolbar {
            if !node.isVirtual {
                Button("Im Finder zeigen", systemImage: "folder") { reveal(node.path) }
                Button("Informationen", systemImage: "info.circle") {
                    info = Row(id: node.path, name: node.name, bytes: node.bytes, items: node.fileCount, kind: .folder(node))
                }
            }
        }
        .sheet(item: $info) { InfoSheet(row: $0) }
    }
}

// MARK: Info sheet

struct InfoSheet: View {
    let row: Row
    @Environment(\.dismiss) private var dismiss
    @State private var profile: Scanner.Profile?

    var body: some View {
        let path = row.path ?? ""
        let isFolder = { if case .folder = row.kind { true } else { false } }()
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey,
                                                                            .localizedTypeDescriptionKey])
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack(spacing: 14) {
                        fileIcon(path).resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name).font(.title3.weight(.semibold)).lineLimit(2)
                            Text(Paths.display(path)).foregroundStyle(.muted).lineLimit(2).textSelection(.enabled)
                        }
                    }
                    Field("Belegt auf dem Datenträger", Fmt.bytes(row.bytes))
                    Field("Art", values?.localizedTypeDescription ?? "–")
                    if let d = values?.contentModificationDate { Field("Geändert", d.formatted(date: .abbreviated, time: .shortened)) }
                    if let d = values?.creationDate { Field("Erstellt", d.formatted(date: .abbreviated, time: .shortened)) }
                }
                if isFolder {
                    Section("Inhalt") {
                        if let p = profile {
                            Field("Dateien", Fmt.count(p.files))
                            Field("Ordner", Fmt.count(p.folders))
                            Field("App-Pakete", Fmt.count(p.packages))
                            if let o = p.oldest, let n = p.newest {
                                Field("Geändert zwischen", "\(o.formatted(date: .numeric, time: .omitted)) und \(n.formatted(date: .numeric, time: .omitted))")
                            }
                        } else {
                            HStack { ProgressView().controlSize(.small); Text("Werte die Dateien aus …").foregroundStyle(.muted) }
                        }
                    }
                    if let p = profile, !p.types.isEmpty {
                        Section("Dateitypen nach Größe") {
                            let top = max(p.types[0].bytes, 1)
                            ForEach(p.types, id: \.ext) { t in
                                HStack(spacing: 10) {
                                    Text(t.ext).frame(width: 110, alignment: .leading)
                                    ProgressView(value: Double(t.bytes) / Double(top)).progressViewStyle(.linear)
                                    Text(Fmt.bytes(t.bytes)).monospacedDigit().frame(width: 76, alignment: .trailing)
                                    Text("\(Fmt.count(t.count)) Dateien").foregroundStyle(.muted).monospacedDigit()
                                        .frame(width: 100, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Im Finder zeigen") { reveal(path) }
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 560, height: isFolder ? 600 : 380)
        .task {
            guard isFolder else { return }
            profile = await Task.detached(priority: .utility) { Scanner.profile(path) }.value
        }
    }
}

// MARK: Large files

struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.largeFileMB) private var minMB = 500
    @State private var files: [FileItem] = []
    @State private var selection: Set<FileItem.ID> = []
    @State private var sort = [KeyPathComparator(\FileItem.bytes, order: .reverse)]
    @State private var info: Row?

    var body: some View {
        Table(files.sorted(using: sort), selection: $selection, sortOrder: $sort) {
            TableColumn("Name", value: \.name) { f in
                Label { Text(f.name).lineLimit(1).truncationMode(.middle) } icon: { fileIcon(f.path).resizable().frame(width: 16, height: 16) }
            }
            TableColumn("Ort", value: \.path) { f in
                Text(Paths.display((f.path as NSString).deletingLastPathComponent)).lineLimit(1).truncationMode(.middle)
            }
            TableColumn("Größe", value: \.bytes) { f in
                Text(Fmt.bytes(f.bytes)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            if let p = ids.first {
                Button("Im Finder zeigen") { reveal(p) }
                Button("Informationen") { info = row(p) }
            }
        } primaryAction: { ids in ids.first.map(reveal) }
        .overlay {
            if model.root.children.isEmpty { NotMeasured() }
            else if files.isEmpty { ContentUnavailableView("Keine Dateien ab \(Fmt.bytes(Int64(minMB) * 1_000_000))", systemImage: "magnifyingglass") }
        }
        .navigationTitle("Große Dateien")
        .navigationSubtitle("\(files.count) Dateien · zusammen \(Fmt.bytes(files.reduce(0) { $0 + $1.bytes }))")
        .toolbar {
            Picker("Mindestgröße", selection: $minMB) {
                ForEach([10, 50, 100, 250, 500, 1000, 5000], id: \.self) { Text("ab \(Fmt.bytes(Int64($0) * 1_000_000))").tag($0) }
            }
            .pickerStyle(.menu)
        }
        .task(id: [minMB, model.revision]) { files = model.files(atLeast: Int64(minMB) * 1_000_000) }
        .sheet(item: $info) { InfoSheet(row: $0) }
    }

    private func row(_ path: String) -> Row {
        let f = files.first { $0.path == path }
        return Row(id: path, name: f?.name ?? "", bytes: f?.bytes ?? 0, items: 1, kind: .file(path))
    }
}

// MARK: Temporary area

struct TempView: View {
    @Environment(AppModel.self) private var model
    private static let parts = [("T", "Temporäre Dateien", "Wird beim Neustart größtenteils geleert."),
                                ("C", "Caches", "Zwischenspeicher von Apps und Systemdiensten."),
                                ("X", "Prüfkopien von Apps", "Kopien, die macOS beim Prüfen von Signaturen anlegt."),
                                ("0", "Systemdienste", "Daten von Hintergrunddiensten.")]

    var body: some View {
        let _ = model.revision
        let area = model.node(at: Paths.tempArea)
        Form {
            Section {
                Note("macOS legt diesen Bereich für jeden Benutzer unter /private/var/folders an. Er ist im Finder versteckt und wird nicht von „Speicher verwalten“ aufgeschlüsselt.")
                Field("Ort", Paths.tempArea)
                Field("Zusammen", area.map { Fmt.bytes($0.bytes) } ?? "–")
            }
            Section("Unterordner") {
                ForEach(Self.parts, id: \.0) { key, title, detail in
                    let n = area?.child(named: key)
                    Button { n.map(model.open) } label: {
                        HStack(spacing: 12) {
                            Text(key).font(.system(.body, design: .monospaced).weight(.semibold)).frame(width: 26, height: 26)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(title)
                                Text(detail).font(.callout).foregroundStyle(.muted)
                            }
                            Spacer()
                            Text(n.map { Fmt.bytes($0.bytes) } ?? "–").monospacedDigit().foregroundStyle(.muted)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(n != nil)
                }
            }
            if !model.copyGroups.isEmpty {
                Section {
                    Button("Prüfkopien ansehen …") { model.pane = .copies }
                }
            }
        }
        .formStyle(.grouped)
        .overlay { if area == nil { NotMeasured() } }
        .navigationTitle("Temporärer Bereich")
    }
}

// MARK: Code-signature copies

struct CopiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = model.copyGroups
        Form {
            Section {
                Note("Beim Prüfen der Signatur legt macOS manchmal vollständige Kopien einer App im Ordner X an. Das sind keine eigenen Programme; macOS erstellt bei Bedarf eine neue. Löschen ist unbedenklich, solange die App beendet ist.")
            }
            ForEach(groups) { CopyGroupSection(group: $0) }
        }
        .formStyle(.grouped)
        .overlay {
            if model.root.children.isEmpty { NotMeasured() }
            else if groups.isEmpty { ContentUnavailableView("Keine Prüfkopien", systemImage: "checkmark.seal", description: Text("Im Ordner X liegen keine Kopien von Apps.")) }
        }
        .navigationTitle("Prüfkopien")
    }
}

struct CopyGroupSection: View {
    let group: CopyGroup
    @Environment(AppModel.self) private var model
    @State private var details: CopyGroup.Details?
    @State private var running = false
    @State private var confirming = false
    @State private var deleting = false
    @State private var error: String?
    @State private var freed: Int64?

    var body: some View {
        let installed = group.installedVersion
        Section {
            HStack(spacing: 12) {
                if let url = group.appURL { fileIcon(url.path).resizable().frame(width: 40, height: 40) }
                else { Image(systemName: "app.dashed").font(.largeTitle) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.appName).font(.headline)
                    Text(group.bundleID).font(.callout).foregroundStyle(.muted)
                }
                Spacer()
                Label(running ? "läuft" : "beendet", systemImage: running ? "play.circle.fill" : "stop.circle")
                    .foregroundStyle(running ? .warn : .good)
            }
            Field("Kopien", details.map { Fmt.count($0.count) } ?? "…")
            Field("Gezählte Größe", Fmt.bytes(group.node.bytes))
            Field("Installierte Version", installed ?? "nicht gefunden")
            if let d = details {
                ForEach(d.versions, id: \.0) { v, n in
                    Field("Version \(v)", "\(Fmt.copies(n)) · \(v == installed ? "aktuell" : "alt")")
                }
                ForEach(d.days, id: \.0) { day, n in
                    Field("Angelegt am \(day.formatted(date: .abbreviated, time: .omitted))", Fmt.copies(n))
                }
            }
            if let freed { Label("Wirklich frei geworden: \(Fmt.bytes(freed))", systemImage: "checkmark.circle.fill").foregroundStyle(.good) }
            if let error { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.bad) }
            HStack {
                if running { Text("Beende \(group.appName) mit ⌘Q, dann lässt sich löschen.").foregroundStyle(.warn) }
                Spacer()
                Button("Im Explorer öffnen") { model.open(group.node) }
                Button("Alle Kopien löschen …", role: .destructive) { confirming = true }
                    .disabled(running || deleting)
            }
        }
        .task(id: group.id) {
            running = group.isRunning
            let g = group
            details = await Task.detached(priority: .utility) { g.details() }.value
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in running = group.isRunning }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in running = group.isRunning }
        .confirmationDialog("\(details?.count ?? 0) Prüfkopien von \(group.appName) löschen?", isPresented: $confirming) {
            Button("Endgültig löschen", role: .destructive) { Task { await delete() } }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Kopien landen nicht im Papierkorb. macOS legt bei Bedarf eine neue an.")
        }
    }

    private func delete() async {
        running = group.isRunning  // checked again at the last moment
        guard !running else { return }
        deleting = true
        error = nil
        do { freed = try await model.delete(group) } catch { self.error = "Nicht alles ließ sich löschen: \(error.localizedDescription)" }
        deleting = false
    }
}

// MARK: Volume

struct VolumeView: View {
    let path: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let v = model.volumes.first(where: { $0.path == path }) {
            Form {
                Section {
                    HStack(spacing: 14) {
                        fileIcon(v.path).resizable().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name).font(.title2.weight(.semibold))
                            Text(v.format).foregroundStyle(.muted)
                        }
                    }
                    StorageBar(segments: [("Belegt", v.used - v.purgeable, .accentColor), ("Von macOS löschbar", v.purgeable, .accentColor.opacity(0.45))],
                               free: v.free, total: v.total)
                    Field("Kapazität", Fmt.bytes(v.total))
                    Field("Belegt", Fmt.bytes(v.used - v.purgeable))
                    Field("Von macOS löschbar", Fmt.bytes(v.purgeable))
                    Field("Frei", Fmt.bytes(v.free))
                    Field("Verfügbar", Fmt.bytes(v.available))
                }
                Section {
                    if v.isRoot {
                        Button("Zum Überblick") { model.pane = .overview }
                    } else if let n = model.node(at: v.path) {
                        Button("Inhalt erkunden") { model.open(n) }
                    } else {
                        Button("Inhalt messen und erkunden") {
                            model.scan([v.path], reset: false)
                            model.pane = .explorer
                        }
                        .disabled(model.scanning)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(v.name)
        } else {
            ContentUnavailableView("Datenträger nicht mehr verbunden", systemImage: "externaldrive.badge.xmark")
        }
    }
}

// MARK: Scan status (sidebar footer)

struct ScanStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.scanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Messe …")
                    Spacer()
                    Button("Abbrechen") { model.cancelScan() }.buttonStyle(.link)
                }
                Text("\(Fmt.count(model.progress.files)) Dateien · \(Fmt.bytes(model.progress.bytes))")
                    .font(.callout).monospacedDigit().foregroundStyle(.muted)
            } else if let t = model.lastScan {
                Text("Gemessen um \(t.formatted(date: .omitted, time: .shortened))").font(.callout)
                Text("\(Fmt.count(model.root.fileCount)) Dateien · \(Fmt.bytes(model.root.bytes))")
                    .font(.callout).monospacedDigit().foregroundStyle(.muted)
            } else {
                Button("Jetzt messen") { model.scan() }
            }
            if model.unreadable > 0 && !model.scanning {
                Button {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                } label: {
                    Text("\(Fmt.count(model.unreadable)) Ordner nicht lesbar – Vollzugriff erlauben …")
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.link)
                .font(.callout)
                .help("Mit Festplattenvollzugriff misst die App auch geschützte Ordner, zum Beispiel von Mail oder Safari.")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
