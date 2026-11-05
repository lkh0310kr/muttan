import Foundation

enum ChordQuality: String, Codable, CaseIterable, Identifiable {
    case major, minor, dominant7, major7, minor7, sus2, sus4, major6, minor6
    case add9, dominant9, diminished, diminished7, halfDiminished7, augmented
    var id: String { rawValue }
    var title: String {
        switch self {
        case .major: "메이저"; case .minor: "마이너"; case .dominant7: "도미넌트 세븐"
        case .major7: "메이저 세븐"; case .minor7: "마이너 세븐"
        case .sus2: "서스펜디드 투"; case .sus4: "서스펜디드 포"
        case .major6: "식스"; case .minor6: "마이너 식스"
        case .add9: "애드 나인"; case .dominant9: "도미넌트 나인"
        case .diminished: "디미니시드"; case .diminished7: "디미니시드 세븐"
        case .halfDiminished7: "하프 디미니시드"; case .augmented: "어그먼티드"
        }
    }
    var suffix: String {
        switch self {
        case .major: ""; case .minor: "m"; case .dominant7: "7"
        case .major7: "maj7"; case .minor7: "m7"; case .sus2: "sus2"; case .sus4: "sus4"
        case .major6: "6"; case .minor6: "m6"; case .add9: "add9"; case .dominant9: "9"
        case .diminished: "dim"; case .diminished7: "dim7"
        case .halfDiminished7: "m7♭5"; case .augmented: "aug"
        }
    }
    var searchName: String {
        switch self {
        case .major: "major"; case .minor: "minor"; case .dominant7: "dominant 7 seventh"
        case .major7: "major 7"; case .minor7: "minor 7"
        case .sus2: "suspended 2"; case .sus4: "suspended 4"
        case .major6: "major 6"; case .minor6: "minor 6"
        case .add9: "add 9"; case .dominant9: "dominant 9"
        case .diminished: "diminished"; case .diminished7: "diminished 7"
        case .halfDiminished7: "half diminished"; case .augmented: "augmented"
        }
    }
    // The common open C7 shape omits the perfect fifth; root, third and seventh remain required.
    var requiredIntervals: Set<Int> { self == .dominant7 ? intervals.subtracting([7]) : intervals }

    var intervals: Set<Int> {
        switch self {
        case .major: [0, 4, 7]; case .minor: [0, 3, 7]; case .dominant7: [0, 4, 7, 10]
        case .major7: [0, 4, 7, 11]; case .minor7: [0, 3, 7, 10]
        case .sus2: [0, 2, 7]; case .sus4: [0, 5, 7]
        case .major6: [0, 4, 7, 9]; case .minor6: [0, 3, 7, 9]
        case .add9: [0, 2, 4, 7]; case .dominant9: [0, 2, 4, 7, 10]
        case .diminished: [0, 3, 6]; case .diminished7: [0, 3, 6, 9]
        case .halfDiminished7: [0, 3, 6, 10]; case .augmented: [0, 4, 8]
        }
    }
}

struct Chord: Codable, Identifiable {
    let id: String
    let symbol: String
    let root: Int
    let quality: ChordQuality
    let voicings: [ChordVoicing]

    static let rootNames = ["C", "C♯ / D♭", "D", "D♯ / E♭", "E", "F", "F♯ / G♭", "G", "G♯ / A♭", "A", "A♯ / B♭", "B"]
    static let rootAliases = [["C"], ["C#", "Db"], ["D"], ["D#", "Eb"], ["E"], ["F"], ["F#", "Gb"], ["G"], ["G#", "Ab"], ["A"], ["A#", "Bb"], ["B"]]

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func matches(query: String, quality filter: ChordQuality?) -> Bool {
        guard filter == nil || quality == filter else { return false }
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty else { return true }
        var names = [symbol, quality.title, quality.searchName]
        for rootName in Self.rootAliases[root] {
            names += [rootName + quality.suffix, "\(rootName) \(quality.searchName)", "\(rootName) \(quality.title)"]
        }
        if quality == .dominant7 {
            names += Self.rootAliases[root].flatMap { ["\($0) seventh", "\($0) 세븐"] }
        }
        if quality == .halfDiminished7 {
            names += Self.rootAliases[root].map { $0 + "ø7" }
        }
        if quality == .augmented { names += Self.rootAliases[root].map { $0 + "+" } }
        return names.contains { Self.normalize($0).contains(normalized) }
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
    func note(at index: Int, includeOctave: Bool = false) -> String? {
        guard frets.indices.contains(index), let fret = frets[index] else { return nil }
        let midi = Self.tuning[index] + fret
        return Self.noteNames[midi % 12] + (includeOctave ? String(midi / 12 - 1) : "")
    }

    var accessibilityDescription: String {
        let strings = frets.indices.map { index in
            guard let fret = frets[index] else { return "\(6 - index)번 현 뮤트" }
            let position = fret == 0 ? "개방현" : "\(fret)프렛, \(fingers[index] ?? 0)번 손가락"
            return "\(6 - index)번 현 \(position), \(note(at: index, includeOctave: true) ?? "")"
        }
        let bars = barres.map { "\($0.finger)번 손가락 바레, \($0.fret)프렛 \($0.fromString)번부터 \($0.toString)번 현" }
        return (strings + bars).joined(separator: ". ")
    }

}

enum ChordCatalog {
    static let result: Result<[Chord], Error> = Result {
        guard let url = Bundle.main.url(forResource: "chords", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [Chord] {
        let chords = try JSONDecoder().decode([Chord].self, from: data)
        var ids = Set<String>()
        for chord in chords {
            guard ids.insert(chord.id).inserted, (0..<12).contains(chord.root), !chord.voicings.isEmpty else { throw CocoaError(.coderReadCorrupt) }
            for voicing in chord.voicings {
                guard ids.insert(voicing.id).inserted, voicing.frets.count == 6, voicing.fingers.count == 6 else { throw CocoaError(.coderReadCorrupt) }
                for (fret, finger) in zip(voicing.frets, voicing.fingers) {
                    guard (fret == nil && finger == nil) || (fret == 0 && finger == 0) || (fret.map { (1...24).contains($0) } == true && finger.map { (1...4).contains($0) } == true) else { throw CocoaError(.coderReadCorrupt) }
                }
                guard voicing.pitches.isSubset(of: Set(chord.quality.intervals.map { ($0 + chord.root) % 12 })), Set(chord.quality.requiredIntervals.map { ($0 + chord.root) % 12 }).isSubset(of: voicing.pitches), voicing.frets.compactMap({ $0 }).filter({ $0 > 0 }).allSatisfy({ $0 < voicing.startFret + 5 }) else { throw CocoaError(.coderReadCorrupt) }
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
