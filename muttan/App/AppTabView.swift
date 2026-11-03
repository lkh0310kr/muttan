import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("학습", systemImage: "music.note.list") }

            TunerView()
                .tabItem { Label("튜너", systemImage: "tuningfork") }

            ProgressViewScreen()
                .tabItem { Label("기록", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .tint(.mint)
    }
}
