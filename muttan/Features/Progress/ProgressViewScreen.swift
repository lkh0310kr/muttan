import SwiftUI

struct ProgressViewScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "아직 연습 기록이 없어요",
                systemImage: "chart.bar",
                description: Text("첫 레슨을 완료하면 정확도와 연습 시간이 여기에 쌓입니다.")
            )
            .navigationTitle("나의 기록")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
