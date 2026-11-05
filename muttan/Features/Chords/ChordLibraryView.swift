import SwiftUI

struct ChordLibraryView: View {
    var snapshotDetail = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""
    @State private var quality: ChordQuality?
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch ChordCatalog.result {
                case .success(let chords): library(chords)
                case .failure:
                    ContentUnavailableView("코드를 불러올 수 없어요", systemImage: "exclamationmark.triangle", description: Text("앱의 코드 데이터를 확인해 주세요."))
                }
            }
            .navigationTitle("코드")
            .navigationDestination(for: String.self) { id in
                if case .success(let chords) = ChordCatalog.result, let chord = chords.first(where: { $0.id == id }) {
                    ChordDetailView(chord: chord)
                }
            }
            .onAppear {
                if snapshotDetail, path.isEmpty { path = ["F"] }
            }
        }
    }

    private func library(_ chords: [Chord]) -> some View {
        let filtered = chords.filter { $0.matches(query: query, quality: quality) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("코드 종류", selection: $quality) {
                    Text("전체").tag(Optional<ChordQuality>.none)
                    ForEach(ChordQuality.allCases) { option in
                        Text(option.title).tag(Optional(option))
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("표준 튜닝 · E A D G B E")
                    Spacer()
                    Text("\(filtered.count)개")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query.trimmingCharacters(in: .whitespacesAndNewlines))
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                        ForEach(filtered) { chord in
                            NavigationLink(value: chord.id) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(chord.symbol).font(.title2.bold())
                                        Spacer()
                                        Text(chord.quality.title).font(.caption).foregroundStyle(.secondary)
                                    }
                                    ChordDiagram(voicing: chord.voicings[0], compact: true)
                                        .frame(height: 128)
                                        .accessibilityHidden(true)
                                }
                                .padding(16)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(chord.symbol), \(chord.quality.title), 운지 보기")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $query, prompt: "코드 검색 · C, Am, A major")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct ChordDetailView: View {
    let chord: Chord
    @State private var voicingIndex = 0
    @State private var showsNotes = false
    private var voicing: ChordVoicing { chord.voicings[voicingIndex] }
    private var notes: String {
        voicing.pitches.sorted { ($0 - chord.root + 12) % 12 < ($1 - chord.root + 12) % 12 }
            .map { ChordVoicing.noteNames[$0] }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(chord.symbol).font(.system(size: 52, weight: .bold, design: .rounded))
                    Text("\(chord.quality.title) · \(notes)").font(.subheadline).foregroundStyle(.secondary)
                }
                Picker("운지", selection: $voicingIndex) {
                    ForEach(chord.voicings.indices, id: \.self) { index in
                        Text(chord.voicings[index].title).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                Picker("운지표 표시", selection: $showsNotes) {
                    Text("손가락 번호").tag(false)
                    Text("음이름").tag(true)
                }
                .pickerStyle(.segmented)
                ChordDiagram(voicing: voicing, showsNotes: showsNotes)
                    .frame(maxWidth: 340)
                    .frame(height: 330)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                HStack(spacing: 16) {
                    Text("○ 개방현")
                    Text("× 뮤트")
                    Text("1–4 손가락")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                stringDetails
                VStack(alignment: .leading, spacing: 8) {
                    Text("표준 튜닝 · 오른손 기타").font(.subheadline.weight(.semibold))
                    Text("왼쪽부터 6번 현입니다. 숫자는 검지(1)부터 소지(4)까지의 손가락 번호이며, 연결된 표시는 바레입니다.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(chord.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stringDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("현별 운지").font(.headline)
            Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("현"); Text("프렛"); Text("손가락"); Text("음")
                }
                .font(.caption).foregroundStyle(.secondary)
                ForEach(0..<6, id: \.self) { index in
                    GridRow {
                        Text("\(6 - index)")
                        Text(voicing.frets[index].map { $0 == 0 ? "개방" : String($0) } ?? "뮤트")
                        Text(voicing.fingers[index].flatMap { $0 == 0 ? nil : String($0) } ?? "—")
                        Text(voicing.note(at: index, includeOctave: true) ?? "—")
                    }
                    .font(.subheadline.monospacedDigit())
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

}

private struct ChordDiagram: View {
    let voicing: ChordVoicing
    var compact = false
    var showsNotes = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let left = w * 0.16
            let top = h * 0.16
            let dx = w * 0.68 / 5
            let dy = h * 0.70 / 5
            let diameter = min(dx * 0.78, dy * 0.80)
            ZStack {
                Canvas { context, _ in
                    var lines = Path()
                    for i in 0...5 {
                        let x = left + CGFloat(i) * dx
                        lines.move(to: CGPoint(x: x, y: top))
                        lines.addLine(to: CGPoint(x: x, y: top + dy * 5))
                        let y = top + CGFloat(i) * dy
                        lines.move(to: CGPoint(x: left, y: y))
                        lines.addLine(to: CGPoint(x: left + dx * 5, y: y))
                    }
                    context.stroke(lines, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                    if voicing.startFret == 1 {
                        var nut = Path()
                        nut.move(to: CGPoint(x: left, y: top))
                        nut.addLine(to: CGPoint(x: left + dx * 5, y: top))
                        context.stroke(nut, with: .color(.primary), lineWidth: compact ? 3 : 5)
                    }
                }
                if voicing.startFret > 1 {
                    Text("\(voicing.startFret)fr")
                        .font(.system(size: compact ? 9 : 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(x: left * 0.36, y: top + dy / 2)
                }
                ForEach(Array(voicing.barres.enumerated()), id: \.offset) { _, barre in
                    let x1 = left + CGFloat(6 - barre.fromString) * dx
                    let x2 = left + CGFloat(6 - barre.toString) * dx
                    Capsule()
                        .fill(Color.mint)
                        .frame(width: x2 - x1 + diameter, height: diameter)
                        .position(x: (x1 + x2) / 2, y: top + (CGFloat(barre.fret - voicing.startFret) + 0.5) * dy)
                }
                ForEach(0..<6, id: \.self) { index in
                    let x = left + CGFloat(index) * dx
                    if let fret = voicing.frets[index], fret > 0 {
                        let barre = voicing.barres.first { $0.fret == fret && $0.finger == voicing.fingers[index] && ( $0.toString...$0.fromString ).contains(6 - index) }
                        let label = showsNotes ? (voicing.note(at: index) ?? "") : (barre == nil || barre?.fromString == 6 - index ? String(voicing.fingers[index] ?? 0) : "")
                        Text(label)
                            .font(.system(size: compact ? 9 : 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: diameter, height: diameter)
                            .background(Color.mint, in: Circle())
                            .position(x: x, y: top + (CGFloat(fret - voicing.startFret) + 0.5) * dy)
                    } else {
                        Text(voicing.frets[index] == nil ? "×" : "○")
                            .font(.system(size: compact ? 13 : 22, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                            .position(x: x, y: top * 0.43)
                    }
                    if !compact {
                        Text(showsNotes ? (voicing.note(at: index) ?? "×") : String(6 - index))
                            .font(.caption2).foregroundStyle(.secondary)
                            .position(x: x, y: top + dy * 5 + 16)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("운지표. \(voicing.accessibilityDescription)")
    }
}
