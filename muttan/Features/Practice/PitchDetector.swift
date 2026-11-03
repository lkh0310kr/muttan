import Foundation

struct PitchEstimate {
    let frequency: Double
    let clarity: Double
}

enum PitchDetector {
    /// YIN's cumulative mean normalized difference function for monophonic notes.
    /// The clarity threshold rejects noisy or chord-like buffers instead of guessing.
    static func estimate(
        samples: [Float],
        sampleRate: Double,
        minimumFrequency: Double = 60,
        maximumFrequency: Double = 1_000
    ) -> PitchEstimate? {
        guard samples.count >= 2_048, sampleRate > 0 else { return nil }

        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        let centered = samples.map { Double($0) - mean }
        let rms = sqrt(centered.reduce(0.0) { $0 + $1 * $1 } / Double(centered.count))
        guard rms > 0.008 else { return nil }

        let minLag = max(2, Int(sampleRate / maximumFrequency))
        let maxLag = min(centered.count / 2, Int(sampleRate / minimumFrequency))
        guard minLag < maxLag else { return nil }

        var difference = [Double](repeating: 0, count: maxLag + 1)
        for lag in 1...maxLag {
            var sum = 0.0
            let end = centered.count - lag
            for index in 0..<end {
                let delta = centered[index] - centered[index + lag]
                sum += delta * delta
            }
            difference[lag] = sum
        }

        var normalized = [Double](repeating: 1, count: maxLag + 1)
        var runningSum = 0.0
        for lag in 1...maxLag {
            runningSum += difference[lag]
            if runningSum > 0 {
                normalized[lag] = difference[lag] * Double(lag) / runningSum
            }
        }

        let threshold = 0.14
        var candidate = minLag
        while candidate <= maxLag, normalized[candidate] >= threshold {
            candidate += 1
        }

        if candidate <= maxLag {
            while candidate < maxLag, normalized[candidate + 1] < normalized[candidate] {
                candidate += 1
            }
        } else {
            candidate = (minLag...maxLag).min { normalized[$0] < normalized[$1] } ?? minLag
            guard normalized[candidate] < 0.25 else { return nil }
        }

        guard candidate > minLag, candidate < maxLag else { return nil }
        let left = normalized[candidate - 1]
        let center = normalized[candidate]
        let right = normalized[candidate + 1]
        let denominator = left - 2 * center + right
        let adjustment = abs(denominator) > 1e-12 ? 0.5 * (left - right) / denominator : 0
        let refinedLag = Double(candidate) + max(-1, min(1, adjustment))
        let frequency = sampleRate / refinedLag
        let clarity = 1 - center

        guard (minimumFrequency...maximumFrequency).contains(frequency), clarity >= 0.75 else { return nil }
        return PitchEstimate(frequency: frequency, clarity: clarity)
    }
}
