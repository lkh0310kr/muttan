import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}
let chords = try JSONDecoder().decode([Chord].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
check(chords.filter { $0.matches(query: " AM \n", quality: nil) }.map(\.symbol) == ["Am"], "Symbol search")
check(chords.filter { $0.matches(query: "A major", quality: nil) }.map(\.symbol) == ["A"], "Full chord name")
check(chords.filter { $0.matches(query: "마이너", quality: .major) }.isEmpty, "Combined filter")
check(chords.filter { $0.matches(query: "마이너", quality: .minor) }.count == 4, "Korean search")
check(chords.filter { $0.matches(query: "", quality: .dominant7) }.count == 2, "Seventh filter")
check(chords.filter { $0.matches(query: "xyz", quality: nil) }.isEmpty, "Empty results")
let f = chords.first { $0.id == "F" }!
check(f.voicings[0].note(at: 0, includeOctave: true) == "F2", "Bass pitch")
check(f.voicings[1].note(at: 0) == nil, "Muted string")
check(f.voicings[0].accessibilityDescription.contains("바레"), "Barre accessibility")
for chord in chords {
    for voicing in chord.voicings {
        check(voicing.pitches == Set(chord.quality.intervals.map { ($0 + chord.root) % 12 }), "Chord tones")
    }
}
print("Chord model checks passed.")

let e = PitchEstimate(frequency: 82.406889, clarity: 0.99)
var state = TunerSignalState()
state.consume(e, capturedAt: 0, now: 0, session: 0)
check(state.reading == nil, "Inactive session rejects callbacks")
let first = state.start()
state.consume(e, capturedAt: 1, now: 1.01, session: first)
check(state.reading?.noteName == "E2", "First valid reading")
state.consume(nil, capturedAt: 1.2, now: 1.21, session: first)
check(state.reading != nil, "Short dropout retains reading")
state.expire(at: 1.61)
check(state.reading == nil, "Silence clears stale pitch")
state.consume(e, capturedAt: 2, now: 2.3, session: first)
check(state.reading == nil, "Delayed result rejected")
state.consume(e, capturedAt: 3, now: 3.01, session: first)
state.stop()
state.consume(e, capturedAt: 3.1, now: 3.11, session: first)
check(state.reading == nil, "Stop cannot be undone by old callback")
let second = state.start()
state.consume(e, capturedAt: 4, now: 4.01, session: first)
check(state.reading == nil, "Restart rejects old session")
state.consume(e, capturedAt: 5, now: 5.01, session: second)
state.consume(PitchEstimate(frequency: 110, clarity: 0.99), capturedAt: 4.99, now: 5.02, session: second)
check(state.reading?.noteName == "E2", "Out of order result rejected")
let before = state.reading!.midi
state.consume(PitchEstimate(frequency: e.frequency * pow(2, 0.1 / 12), clarity: 0.99), capturedAt: 5.1, now: 5.11, session: second)
check(abs(state.reading!.midi - before - 0.035) < 0.00001, "Pitch smoothing")
state.consume(PitchEstimate(frequency: .infinity, clarity: 1), capturedAt: 5.2, now: 5.21, session: second)
check(state.reading!.midi.isFinite, "Invalid frequency rejected")
state.expire(at: 5.8)
check(state.reading == nil, "Watchdog expires without audio callbacks")
for tuning in GuitarTuning.allCases {
    for string in GuitarString.allCases {
        let midi = Double(tuning.midi(for: string))
        check(tuning.nearestString(to: midi + 0.4) == string, "Auto target sharp")
        check(tuning.nearestString(to: midi - 0.4) == string, "Auto target flat")
    }
}
check(GuitarTuning.standard.nearestString(to: 69) == nil, "Unrelated octave is not in tune")
check(GuitarTuning.dropD.midi(for: .lowE) == 38, "Drop D target")
check(GuitarTuning.standard.nearestString(to: 41) == .lowE, "F2 must target E2 rather than count as tuned F")
print("Tuner session, expiry, smoothing and target checks passed.")

for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
    for frequency in [73.416192, 77.781746, 82.406889, 110, 146.832384, 195.997718, 246.941651, 329.627557] {
        let samples = (0..<4096).map { i -> Float in
            let phase = 2 * Double.pi * frequency * Double(i) / sampleRate
            return Float(0.15 * sin(phase) + 0.07 * sin(2 * phase) + 0.04 * sin(3 * phase))
        }
        guard let estimate = PitchDetector.estimate(samples: samples, sampleRate: sampleRate) else { fatalError("No pitch for \(frequency) at \(sampleRate)") }
        let cents = 1200 * log2(estimate.frequency / frequency)
        check(abs(cents) < 4, "Pitch error \(cents) cents for \(frequency) at \(sampleRate)")
    }
}
let silence = [Float](repeating: 0, count: 4096)
check(PitchDetector.estimate(samples: silence, sampleRate: 48000) == nil, "Silence")
check(PitchDetector.estimate(samples: silence, sampleRate: .infinity) == nil, "Invalid sample rate")
check(PitchDetector.estimate(samples: silence, sampleRate: 48000, minimumFrequency: 0) == nil, "Invalid frequency bounds")
var seed: UInt64 = 42
let noise = (0..<4096).map { _ -> Float in
    seed = seed &* 6364136223846793005 &+ 1
    return Float(Double(seed >> 32) / Double(UInt32.max) - 0.5) * 0.2
}
check(PitchDetector.estimate(samples: noise, sampleRate: 48000) == nil, "Broadband noise")
print("Pitch estimator checks passed: guitar notes, harmonics, three sample rates, silence, noise and invalid input.")

let routes = HeadstockStringRoute.all
check(Set(routes.map(\.string)).count == 6, "Six distinct string routes")
for (index, route) in routes.enumerated() {
    check(route.string == GuitarString.allCases[index], "Routes keep string IDs")
    check(route.nut.y == HeadstockStringRoute.nutY && route.nut.y > route.post.y, "Nut below posts")
    check((0...1).contains(route.nut.x) && (0...1).contains(route.post.x), "Normalized headstock points")
    check(index < 3 ? route.post.x < 0.5 : route.post.x > 0.5, "Three posts per side")
}
func stringX(_ route: HeadstockStringRoute, at y: CGFloat) -> CGFloat {
    let fraction = (y - route.post.y) / (route.nut.y - route.post.y)
    return route.post.x + fraction * (route.nut.x - route.post.x)
}
for i in 0..<routes.count {
    for j in (i + 1)..<routes.count {
        let top = max(routes[i].post.y, routes[j].post.y)
        for step in 0...100 {
            let y = top + (HeadstockStringRoute.nutY - top) * CGFloat(step) / 100
            check(stringX(routes[i], at: y) < stringX(routes[j], at: y), "Guitar strings must never cross")
        }
    }
}
print("Headstock routing checks passed: six posts, ordered nut slots and no crossed strings.")
