import SwiftUI

struct AppTabView: View {
    private let launchArguments = ProcessInfo.processInfo.arguments
    @State private var selectedTab = ProcessInfo.processInfo.arguments
        .first(where: { $0.hasPrefix("--ui-snapshot=") })
        .map { String($0.dropFirst("--ui-snapshot=".count)) }
        .map { ["chord-detail", "chord-chart"].contains($0) ? "chords" : $0 } ?? "chords"

    private var snapshotAppearance: ColorScheme? {
        guard let argument = launchArguments.first(where: { $0.hasPrefix("--ui-snapshot-appearance=") }) else { return nil }
        return argument.hasSuffix("=dark") ? .dark : .light
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChordLibraryView(snapshotDetail: launchArguments.contains("--ui-snapshot=chord-detail"),
                             snapshotChart: launchArguments.contains("--ui-snapshot=chord-chart"))
                .tabItem { Label("코드", systemImage: "guitars") }
                .tag("chords")

            TunerView(screenshotMode: ProcessInfo.processInfo.arguments.contains("--ui-snapshot-mode"))
                .tabItem { Label("튜너", systemImage: "tuningfork") }
                .tag("tuner")

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag("settings")
        }
        .tint(.instrumentAccent)
        .preferredColorScheme(snapshotAppearance)
    }
}
