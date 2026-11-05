import Foundation

enum GuitarString: String, CaseIterable, Identifiable {
    case lowE, a, d, g, b, highE

    var id: String { rawValue }
    var number: Int { 6 - (GuitarString.allCases.firstIndex(of: self) ?? 0) }
    var standardMIDINote: Int {
        switch self {
        case .lowE: 40
        case .a: 45
        case .d: 50
        case .g: 55
        case .b: 59
        case .highE: 64
        }
    }
}

enum GuitarTuning: String, CaseIterable, Identifiable {
    case standard, dropD, halfStepDown

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: "Standard"
        case .dropD: "Drop D"
        case .halfStepDown: "Half step down"
        }
    }

    func midi(for string: GuitarString) -> Int {
        let base = string.standardMIDINote
        switch (self, string) {
        case (.dropD, .lowE): return base - 2
        case (.halfStepDown, _): return base - 1
        default: return base
        }
    }
}


extension GuitarTuning {
    func nearestString(to midi: Double) -> GuitarString? {
        guard midi.isFinite, let closest = GuitarString.allCases.min(by: { abs(Double(self.midi(for: $0)) - midi) < abs(Double(self.midi(for: $1)) - midi) }), abs(Double(self.midi(for: closest)) - midi) <= 2 else { return nil }
        return closest
    }
}

struct TunerPitchReading {
    let midi: Double
    var frequency: Double { 440 * pow(2, (midi - 69) / 12) }
    var noteName: String {
        let note = Int(midi.rounded())
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return "\(names[(note % 12 + 12) % 12])\(note / 12 - 1)"
    }
}

/// Monotonic capture times and session IDs prevent old audio from restoring stale UI.
struct TunerSignalState {
    private(set) var session = 0
    private(set) var isActive = false
    private(set) var reading: TunerPitchReading?
    private var lastValidTime: TimeInterval?
    private var lastProcessedTime: TimeInterval?
    static let expiryInterval: TimeInterval = 0.6
    static let maximumResultAge: TimeInterval = 0.25

    mutating func start() -> Int {
        stop()
        isActive = true
        return session
    }

    mutating func stop() {
        session += 1
        isActive = false
        reading = nil
        lastValidTime = nil
        lastProcessedTime = nil
    }

    mutating func consume(_ estimate: PitchEstimate?, capturedAt: TimeInterval, now: TimeInterval, session token: Int) {
        guard isActive, token == session, capturedAt.isFinite, now.isFinite,
              now >= capturedAt, now - capturedAt <= Self.maximumResultAge,
              lastProcessedTime.map({ capturedAt >= $0 }) ?? true else { return }
        lastProcessedTime = capturedAt
        expire(at: now)
        guard let estimate, estimate.frequency.isFinite, (60...1_000).contains(estimate.frequency), estimate.clarity.isFinite, estimate.clarity >= 0.75 else { return }
        let raw = 69 + 12 * log2(estimate.frequency / 440)
        let smoothed = reading.map { abs(raw - $0.midi) < 2 ? $0.midi * 0.65 + raw * 0.35 : raw } ?? raw
        reading = TunerPitchReading(midi: smoothed)
        lastValidTime = capturedAt
    }

    mutating func expire(at now: TimeInterval) {
        if let lastValidTime, now - lastValidTime >= Self.expiryInterval {
            reading = nil
            self.lastValidTime = nil
        }
    }
}
