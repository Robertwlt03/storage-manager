import AppKit
import SwiftUI

@main
enum Main {
    @MainActor static func main() {
        Prefs.register()
        let args = CommandLine.arguments
        if args.contains("--check-contrast") { exit(Theme.checkContrast() ? 0 : 1) }
        if args.contains("--selftest") {
            Task.detached { selfTest(); exit(0) }
            dispatchMain()
        }
        if let i = args.firstIndex(of: "--render-icon"), i + 1 < args.count {
            let renderer = ImageRenderer(content: AppIconView())
            guard let cg = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]),
                  (try? png.write(to: URL(fileURLWithPath: args[i + 1]))) != nil
            else { exit(1) }
            exit(0)
        }
        SpeicherExplorerApp.main()
    }
}

struct SpeicherExplorerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Speicher-Explorer", id: "main") {
            RootView().environment(model).frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Neu messen") { model.scan() }.keyboardShortcut("r").disabled(model.scanning)
                Button("Messung abbrechen") { model.cancelScan() }.keyboardShortcut(".").disabled(!model.scanning)
            }
        }
        Settings {
            SettingsView().environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.appearance) private var appearance = 0
    @AppStorage(Prefs.binaryUnits) private var binaryUnits = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.pane) {
                Section {
                    Label("Überblick", systemImage: "chart.bar.xaxis").tag(Pane.overview)
                    Label("Ordner", systemImage: "folder").tag(Pane.explorer)
                    Label("Große Dateien", systemImage: "doc.viewfinder").tag(Pane.largeFiles)
                }
                Section("macOS") {
                    Label("Temporärer Bereich", systemImage: "hourglass").tag(Pane.temp)
                    Label("Prüfkopien", systemImage: "checkmark.seal").tag(Pane.copies)
                }
                Section("Datenträger") {
                    ForEach(model.volumes) { v in Label(v.name, systemImage: v.symbol).tag(Pane.volume(v.path)) }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { ScanStatus() }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            Group {
                switch model.pane ?? .overview {
                case .overview: OverviewView()
                case .explorer: ExplorerView()
                case .largeFiles: LargeFilesView()
                case .temp: TempView()
                case .copies: CopiesView()
                case .volume(let path): VolumeView(path: path)
                }
            }
            .id(binaryUnits)  // re-render sizes when the unit setting changes
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Neu messen", systemImage: "arrow.clockwise") { model.scan() }
                    .disabled(model.scanning)
                    .help("Alle Bereiche neu messen (⌘R)")
            }
        }
        .onAppear {
            // `open … --args -pane copies` opens a section directly (handy for screenshots and docs)
            let panes: [String: Pane] = ["overview": .overview, "explorer": .explorer, "largeFiles": .largeFiles, "temp": .temp, "copies": .copies]
            if let p = UserDefaults.standard.string(forKey: "pane").flatMap({ panes[$0] }) { model.pane = p }
            if UserDefaults.standard.bool(forKey: "openSettings") { openSettings() }
            model.autoScanIfWanted()
        }
        .onChange(of: appearance, initial: true) { _, a in
            NSApp.appearance = a == 1 ? NSAppearance(named: .aqua) : a == 2 ? NSAppearance(named: .darkAqua) : nil
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in model.volumes = VolumeInfo.all() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in model.volumes = VolumeInfo.all() }
    }
}

struct SettingsView: View {
    @AppStorage(Prefs.appearance) private var appearance = 0
    @AppStorage(Prefs.palette) private var palette = 0
    @AppStorage(Prefs.binaryUnits) private var binaryUnits = false
    @AppStorage(Prefs.autoScan) private var autoScan = true
    @AppStorage(Prefs.eco) private var eco = true
    @AppStorage(Prefs.pauseOnLowPower) private var pauseOnLowPower = true
    @AppStorage(Prefs.extraFolders) private var extraFolders = ""
    @State private var selectedFolder: String?

    var body: some View {
        TabView {
            Form {
                Picker("Erscheinungsbild", selection: $appearance) {
                    Text("Wie das System").tag(0)
                    Text("Hell").tag(1)
                    Text("Dunkel").tag(2)
                }
                Picker("Diagrammfarben", selection: $palette) {
                    Text("Bunt").tag(0)
                    Text("Akzentfarbe").tag(1)
                    Text("Grautöne").tag(2)
                }
                Toggle(isOn: $binaryUnits) {
                    Text("Binäre Einheiten (GiB)")
                    Text("Aus: Größen wie im Finder, 1 GB = 1000 MB.").foregroundStyle(.muted)
                }
            }
            .frame(height: 210)
            .tabItem { Label("Darstellung", systemImage: "paintbrush") }

            Form {
                Toggle("Beim Start automatisch messen", isOn: $autoScan)
                Toggle(isOn: $pauseOnLowPower) {
                    Text("Im Stromsparmodus nicht automatisch messen")
                    Text("Dann misst die App erst, wenn du auf „Neu messen“ klickst.").foregroundStyle(.muted)
                }
                Toggle(isOn: $eco) {
                    Text("Energiesparend messen")
                    Text("Misst mit niedriger Priorität auf den Effizienzkernen. Das dauert etwas länger, braucht aber deutlich weniger Strom und hält den Mac kühl.")
                        .foregroundStyle(.muted)
                }
                LabeledContent("Zusätzliche Ordner") {
                    VStack(alignment: .leading, spacing: 6) {
                        let folders = extraFolders.split(separator: "\n").map(String.init)
                        List(folders, id: \.self, selection: $selectedFolder) { Text(Paths.display($0)).lineLimit(1).truncationMode(.middle) }
                            .frame(height: 90)
                            .overlay { if folders.isEmpty { Text("Keine").foregroundStyle(.muted) } }
                        HStack(spacing: 4) {
                            Button("Hinzufügen", systemImage: "plus") { addFolder() }.labelStyle(.iconOnly)
                            Button("Entfernen", systemImage: "minus") {
                                extraFolders = folders.filter { $0 != selectedFolder }.joined(separator: "\n")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(selectedFolder == nil)
                        }
                    }
                }
            }
            .frame(height: 430)
            .tabItem { Label("Messen", systemImage: "gauge.with.dots.needle.50percent") }
        }
        .formStyle(.grouped)
        .frame(width: 520)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let all = extraFolders.split(separator: "\n").map(String.init) + panel.urls.map { Paths.real($0.path) }
        extraFolders = Array(NSOrderedSet(array: all)).compactMap { $0 as? String }.joined(separator: "\n")
    }
}

/// `--selftest`: scans real data and prints only counts, sizes and times, never names.
func selfTest() {
    func cpu() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6
    }
    func du(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-sk", path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try? p.run()
        let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (Int64(s.prefix { $0 != "\t" }) ?? 0) * 1024
    }

    let root = Node(name: "", parent: nil)
    for path in [Paths.home, "/Applications", Paths.tempArea] {
        let (start, cpu0) = (Date(), cpu())
        var unreadable = 0
        guard let node = Scanner.scan(path, unreadable: &unreadable, progress: { _ in }) else { fatalError("scan failed") }
        let (secs, cpuSecs) = (Date().timeIntervalSince(start), cpu() - cpu0)
        node.attach(to: root)
        func count(_ n: Node) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
        let reference = du(path)
        let diff = abs(Double(node.bytes - reference)) / Double(max(reference, 1))
        print("Bereich \(root.children.count): \(Fmt.count(node.fileCount)) Dateien, \(Fmt.bytes(node.bytes)) (du: \(Fmt.bytes(reference)), Abweichung \(String(format: "%.2f", diff * 100)) %), \(count(node)) Ordner im Baum, \(unreadable) nicht lesbar, \(String(format: "%.1f", secs)) s, CPU \(String(format: "%.1f", cpuSecs)) s")
        precondition(diff < 0.02, "scanner and du differ by more than 2 %")
    }
    let cats = Categories.compute(root: root, volume: VolumeInfo.all().first { $0.isRoot })
    precondition(!cats.isEmpty && zip(cats, cats.dropFirst()).allSatisfy { $0.bytes >= $1.bytes })
    print("Kategorien: \(cats.count), zusammen \(Fmt.bytes(cats.reduce(0) { $0 + $1.bytes }))")
    for c in cats { print("  \(c.title): \(Fmt.bytes(c.bytes))") }
    print("Volumes: \(VolumeInfo.all().count)")
}
