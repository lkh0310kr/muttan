import SwiftUI

struct HomeView: View {
    private let lessons = [
        Lesson(title: "첫 음정 연주하기", subtitle: "기초 · 10분", symbol: "music.note", progress: 0.35),
        Lesson(title: "오픈 코드 익히기", subtitle: "코드 · 15분", symbol: "guitars", progress: 0)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    streakCard

                    VStack(alignment: .leading, spacing: 14) {
                        sectionTitle("오늘의 학습", action: "전체 보기")
                        ForEach(lessons) { lesson in
                            LessonCard(lesson: lesson)
                        }
                    }

                    Button {} label: {
                        Label("튜닝하고 연습 시작", systemImage: "tuningfork")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("muttan")
            .toolbarTitleDisplayMode(.large)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("안녕하세요!")
                .font(.largeTitle.bold())
            Text("오늘도 기타와 함께 한 걸음씩.")
                .foregroundStyle(.secondary)
        }
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .frame(width: 56, height: 56)
                .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text("연습 스트릭")
                    .font(.headline)
                Text("첫 연습을 시작해 기록을 만들어 보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func sectionTitle(_ title: String, action: String) -> some View {
        HStack {
            Text(title).font(.title2.bold())
            Spacer()
            Button(action) {}
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.mint)
        }
    }
}

private struct Lesson: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let progress: Double
}

private struct LessonCard: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: lesson.symbol)
                    .font(.title2)
                    .foregroundStyle(.mint)
                    .frame(width: 50, height: 50)
                    .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(lesson.title).font(.headline)
                    Text(lesson.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            if lesson.progress > 0 {
                ProgressView(value: lesson.progress)
                    .tint(.mint)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
