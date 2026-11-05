import Foundation

enum ChordQuality: String, Codable, CaseIterable, Identifiable {
    case major, minor, dominant7
    var id: String { rawValue }
    var title: String {
        switch self { case .major: "Major"; case .minor: "Minor"; case .dominant7: "7" }
    }
    var intervals: Set<Int> {
        switch self { case .major: [0, 4, 7]; case .minor: [0, 3, 7]; case .dominant7: [0, 4, 7, 10] }
    }
}

struct Chord: Codable, Identifiable {
    let id: String
    let symbol: String
    let root: Int
    let quality: ChordQuality
    let voicings: [ChordVoicing]

    func matches(query: String, quality filter: ChordQuality?) -> Bool {
        (filter == nil || quality == filter) && (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || symbol.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}

struct ChordVoicing: Codable, Identifiable {
    struct Barre: Codable {
        let fret: Int
        let fromString: Int
        let toString: Int
        let finger: Int
    }
    static let tuning = [40, 45, 50, 55, 59, 64]
    static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let id: String
    let title: String
    let frets: [Int?]
    let fingers: [Int?]
    let barres: [Barre]
    var startFret: Int {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        return (fretted.max() ?? 0) <= 4 ? 1 : (fretted.min() ?? 1)
    }
    var pitches: Set<Int> {
        Set(zip(Self.tuning, frets).compactMap { note, fret in fret.map { (note + $0) % 12 } })
    }
    var accessibilityDescription: String {
        frets.indices.map { index in
            guard let fret = frets[index] else { return "\(6 - index)번 현 뮤트" }
            if fret == 0 { return "\(6 - index)번 현 개방현" }
            return "\(6 - index)번 현 \(fret)프렛, \(fingers[index] ?? 0)번 손가락"
        }.joined(separator: ". ")
    }
}

enum ChordCatalog {
    static let result: Result<[Chord], Error> = Result {
        guard let url = Bundle.main.url(forResource: "chords", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let chords = try JSONDecoder().decode([Chord].self, from: Data(contentsOf: url))
        var ids = Set<String>()
        for chord in chords {
            guard ids.insert(chord.id).inserted, (0..<12).contains(chord.root), chord.voicings.count == 2 else { throw CocoaError(.coderReadCorrupt) }
            for voicing in chord.voicings {
                guard ids.insert(voicing.id).inserted, voicing.frets.count == 6, voicing.fingers.count == 6 else { throw CocoaError(.coderReadCorrupt) }
                for (fret, finger) in zip(voicing.frets, voicing.fingers) {
                    guard (fret == nil && finger == nil) || (fret == 0 && finger == 0) || (fret.map { (1...24).contains($0) } == true && finger.map { (1...4).contains($0) } == true) else { throw CocoaError(.coderReadCorrupt) }
                }
                guard voicing.pitches == Set(chord.quality.intervals.map { ($0 + chord.root) % 12 }), voicing.frets.compactMap({ $0 }).filter({ $0 > 0 }).allSatisfy({ $0 < voicing.startFret + 5 }) else { throw CocoaError(.coderReadCorrupt) }
                for barre in voicing.barres {
                    guard (1...6).contains(barre.toString), (barre.toString...6).contains(barre.fromString), (1...4).contains(barre.finger), (voicing.startFret..<voicing.startFret + 5).contains(barre.fret) else { throw CocoaError(.coderReadCorrupt) }
                    for string in barre.toString...barre.fromString {
                        guard let fret = voicing.frets[6 - string], fret >= barre.fret else { throw CocoaError(.coderReadCorrupt) }
                    }
                }
            }
        }
        return chords
    }
}
