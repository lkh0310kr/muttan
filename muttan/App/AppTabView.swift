import SwiftUI

struct AppTabView: View {
    private let launchArguments = ProcessInfo.processInfo.arguments
    @State private var selectedTab = ProcessInfo.processInfo.arguments
        .first(where: { $0.hasPrefix("--ui-snapshot=") })
        .map { String($0.dropFirst("--ui-snapshot=".count)) } ?? "home"

    private var snapshotAppearance: ColorScheme? {
        guard let argument = launchArguments.first(where: { $0.hasPrefix("--ui-snapshot-appearance=") }) else { return nil }
        return argument.hasSuffix("=dark") ? .dark : .light
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("학습", systemImage: "music.note.list") }
                .tag("home")

            TunerView(screenshotMode: ProcessInfo.processInfo.arguments.contains("--ui-snapshot-mode"))
                .tabItem { Label("튜너", systemImage: "tuningfork") }
                .tag("tuner")

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag("settings")
        }
        .tint(.mint)
        .preferredColorScheme(snapshotAppearance)
    }
}
