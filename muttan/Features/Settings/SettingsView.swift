import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("연습") {
                    Label("오디오 입력", systemImage: "mic")
                    Label("연습 목표", systemImage: "target")
                }
                Section("앱") {
                    Label("언어", systemImage: "globe")
                    Label("개인정보 처리방침", systemImage: "hand.raised")
                }
            }
            .navigationTitle("설정")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
