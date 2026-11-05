import SwiftUI

struct AppTabView: View {
    private let launchArguments = ProcessInfo.processInfo.arguments
    @State private var selectedTab: String

    init() {
        let snapshot = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--ui-snapshot=") })
            .map { String($0.dropFirst("--ui-snapshot=".count)) }
        switch snapshot {
        case "chord-detail", "chord-chart": _selectedTab = State(initialValue: "chords")
        case "tuner": _selectedTab = State(initialValue: "tuner")
        case "songs", "song-play": _selectedTab = State(initialValue: "songs")
        case "settings": _selectedTab = State(initialValue: "settings")
        default: _selectedTab = State(initialValue: "practice")
        }
    }

    private var snapshotAppearance: ColorScheme? {
        guard let argument = launchArguments.first(where: { $0.hasPrefix("--ui-snapshot-appearance=") }) else { return nil }
        return argument.hasSuffix("=dark") ? .dark : .light
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PracticeLibraryView(snapshotMode: launchArguments.contains("--ui-snapshot=practice-play"),
                                isActive: selectedTab == "practice")
                .tabItem { Label("연습", systemImage: "metronome") }
                .tag("practice")

            SongLibraryView(snapshotMode: launchArguments.contains("--ui-snapshot=song-play"),
                            isActive: selectedTab == "songs")
                .tabItem { Label("곡", systemImage: "music.note.list") }
                .tag("songs")

            ChordLibraryView(snapshotDetail: launchArguments.contains("--ui-snapshot=chord-detail"),
                             snapshotChart: launchArguments.contains("--ui-snapshot=chord-chart"))
                .tabItem { Label("코드", systemImage: "guitars") }
                .tag("chords")

            TunerView(screenshotMode: ProcessInfo.processInfo.arguments.contains("--ui-snapshot-mode"),
                      isActive: selectedTab == "tuner")
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
