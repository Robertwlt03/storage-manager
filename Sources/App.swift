import AppKit
import SwiftUI

@main
enum Main {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if args.contains("--check-contrast") { exit(Theme.checkContrast() ? 0 : 1) }
        if args.contains("--selftest") {
            Task { await Disk.selfTest(); exit(0) }
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

enum Area: String, CaseIterable, Identifiable {
    case overview, temp, chrome, explorer, bigFiles
    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Überblick"
        case .temp: "Temporärer Bereich"
        case .chrome: "Chrome-Prüfkopien"
        case .explorer: "Ordner erkunden"
        case .bigFiles: "Große Dateien"
        }
    }

    var art: [String] {
        switch self {
        case .overview: Art.drive
        case .temp: Art.hourglass
        case .chrome: Art.chrome
        case .explorer: Art.folder
        case .bigFiles: Art.magnifier
        }
    }
}

@Observable final class AppState {
    var area: Area? = Area(rawValue: UserDefaults.standard.string(forKey: "area") ?? "") ?? .overview  // `--args -area chrome`
    var explorerDir = Disk.home

    func explore(_ url: URL) {
        explorerDir = url
        area = .explorer
    }
}

struct SpeicherExplorerApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView().environment(app).frame(minWidth: 980, minHeight: 640)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    /// Screens stay alive once opened, so switching back does not measure again.
    @State private var visited: Set<Area> = [.overview]

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            List(Area.allCases, selection: $app.area) { a in
                Label { Text(a.title) } icon: { PixelTile(rows: a.art, pixel: 1.4) }
                    .padding(.vertical, 3)
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    PixelTile(rows: Art.donut(Disk.volume().fraction), pixel: 2.4)
                    Text("Speicher-Explorer").font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            ZStack {
                ForEach(Area.allCases.filter(visited.contains)) { a in
                    screen(a)
                        .opacity(app.area == a ? 1 : 0)
                        .allowsHitTesting(app.area == a)
                        .accessibilityHidden(app.area != a)
                }
            }
            .background(.bg)
            .navigationTitle(app.area?.title ?? "Speicher-Explorer")
        }
        .onChange(of: app.area, initial: true) { _, a in if let a { visited.insert(a) } }
    }

    @ViewBuilder private func screen(_ a: Area) -> some View {
        switch a {
        case .overview: OverviewScreen()
        case .temp: TempScreen()
        case .chrome: ChromeScreen()
        case .explorer: ExplorerScreen()
        case .bigFiles: BigFilesScreen()
        }
    }
}
