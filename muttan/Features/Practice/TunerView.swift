import AVFoundation
import SwiftUI

struct TunerView: View {
    @StateObject private var tuner = GuitarTuner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text(tuner.noteName ?? "—")
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(tuner.frequency.map { String(format: "%.1f Hz", $0) } ?? "기타 줄을 하나씩 튕겨보세요")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TuningMeter(cents: tuner.cents)
                    HStack {
                        Text("낮음")
                        Spacer()
                        Text(tuner.cents.map { abs($0) <= 5 ? "정확해요!" : String(format: "%+.0f cent", $0) } ?? "대기 중")
                            .fontWeight(.semibold)
                            .foregroundStyle(tuner.isInTune ? .mint : .secondary)
                        Spacer()
                        Text("높음")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)

                Text(tuner.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    tuner.isListening ? tuner.stop() : tuner.start()
                } label: {
                    Label(tuner.isListening ? "튜너 멈추기" : "튜너 시작", systemImage: tuner.isListening ? "stop.fill" : "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .padding(.horizontal, 30)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("튜닝")
            .toolbarTitleDisplayMode(.inline)
            .onAppear { DebugLog.record("screen.tuner.appear") }
            .onDisappear { tuner.stop() }
        }
    }
}

private struct TuningMeter: View {
    let cents: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                Capsule().fill(Color.secondary.opacity(0.12)).frame(height: 8)
                HStack(spacing: 0) {
                    ForEach(0..<nineTicks, id: \.self) { _ in
                        Rectangle().fill(Color.secondary.opacity(0.28)).frame(width: 2, height: 12)
                        Spacer(minLength: 0)
                    }
                    Rectangle().fill(Color.secondary.opacity(0.28)).frame(width: 2, height: 12)
                }
                .padding(.horizontal, 4)
                Rectangle()
                    .fill(cents.map { abs($0) <= 5 ? Color.mint : Color.primary } ?? Color.secondary)
                    .frame(width: 4, height: 30)
                    .offset(x: CGFloat(max(-50, min(50, cents ?? 0)) / 50) * (width / 2 - 8))
                    .animation(.easeOut(duration: 0.12), value: cents)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 32)
    }

    private let nineTicks = 9
}

private final class AudioLogGate: @unchecked Sendable {
    private let lock = NSLock()
    private var lastLog = Date.distantPast

    func shouldLog(interval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard Date().timeIntervalSince(lastLog) >= interval else { return false }
        lastLog = Date()
        return true
    }
}

@MainActor
private final class GuitarTuner: ObservableObject {
    @Published private(set) var frequency: Double?
    @Published private(set) var noteName: String?
    @Published private(set) var cents: Double?
    @Published private(set) var isListening = false
    @Published private(set) var statusMessage = "튜너를 시작하고 기타 소리를 들려주세요."

    var isInTune: Bool { cents.map { abs($0) <= 5 } ?? false }

    private let engine = AVAudioEngine()
    private var lastUpdate = Date.distantPast
    private let notes = ["도", "도♯", "레", "레♯", "미", "파", "파♯", "솔", "솔♯", "라", "라♯", "시"]
    private let noPitchLogGate = AudioLogGate()
    private var lastPitchLog = Date.distantPast
    private var isStarting = false
    private var tapInstalled = false
    private var startAttempt = 0

    func start() {
        guard !isListening, !isStarting else {
            DebugLog.record("tuner.start.ignored", details: [
                "isListening": String(isListening),
                "isStarting": String(isStarting)
            ])
            return
        }
        isStarting = true
        startAttempt += 1
        let attempt = startAttempt
        DebugLog.record("tuner.start.requested")
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard self.startAttempt == attempt else {
                    DebugLog.record("tuner.start.cancelled", details: ["reason": "stale_permission_callback"])
                    return
                }
                DebugLog.record("tuner.microphone.permission", details: ["granted": String(granted)])
                guard granted else {
                    self.isStarting = false
                    self.statusMessage = "마이크 권한이 필요합니다. 설정에서 muttan의 마이크 접근을 허용해주세요."
                    return
                }
                self.startEngine()
            }
        }
    }

    func stop() {
        startAttempt += 1
        isStarting = false
        guard isListening || engine.isRunning || tapInstalled else { return }
        DebugLog.record("tuner.stop", details: ["engineRunning": String(engine.isRunning)])
        removeInputTapIfNeeded()
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
        frequency = nil
        noteName = nil
        cents = nil
        statusMessage = "튜너를 시작하고 기타 소리를 들려주세요."
    }

    private func startEngine() {
        defer { isStarting = false }
        do {
            // Recover any tap left behind by a previous partial start before installing another.
            if engine.isRunning { engine.stop() }
            removeInputTapIfNeeded()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.channelCount > 0 else {
                DebugLog.record("tuner.audio.no_input", details: ["sampleRate": String(format.sampleRate)])
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                statusMessage = "마이크 입력을 사용할 수 없습니다."
                return
            }
            DebugLog.record("tuner.audio.format", details: [
                "sampleRate": String(format.sampleRate),
                "channels": String(format.channelCount),
                "bufferFrames": "4096"
            ])
            let noPitchLogGate = self.noPitchLogGate
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee else { return }
                let count = Int(buffer.frameLength)
                let samples = (0..<count).filter { $0.isMultiple(of: 2) }.map { channel[$0] }
                guard let pitch = Self.detectPitch(samples: samples, sampleRate: format.sampleRate / 2) else {
                    if noPitchLogGate.shouldLog(interval: 5) {
                        DebugLog.record("tuner.audio.no_pitch", details: ["frames": String(count)])
                    }
                    return
                }
                Task { @MainActor in self?.update(with: pitch) }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            isListening = true
            statusMessage = "줄을 하나씩 튕겨보세요."
            DebugLog.record("tuner.audio.started")
        } catch {
            removeInputTapIfNeeded()
            if engine.isRunning { engine.stop() }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            statusMessage = "마이크를 시작하지 못했어요: \(error.localizedDescription)"
            isListening = false
            DebugLog.record("tuner.audio.start_failed", details: ["error": error.localizedDescription], level: .error)
        }
    }

    private func removeInputTapIfNeeded() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
        DebugLog.record("tuner.audio.tap_removed")
    }

    private func update(with frequency: Double) {
        guard Date().timeIntervalSince(lastUpdate) > 0.08 else { return }
        lastUpdate = Date()
        let midi = 69 + 12 * log2(frequency / 440)
        let rounded = Int(midi.rounded())
        let index = (rounded % 12 + 12) % 12
        self.frequency = frequency
        noteName = notes[index]
        cents = (midi - Double(rounded)) * 100
        statusMessage = "가장 가까운 음: \(notes[index]) · 표준 튜닝 기준"
        if Date().timeIntervalSince(lastPitchLog) >= 1 {
            lastPitchLog = Date()
            DebugLog.record("tuner.pitch", details: [
                "frequencyHz": String(format: "%.2f", frequency),
                "note": notes[index],
                "cents": String(format: "%.1f", self.cents ?? 0)
            ])
        }
    }

    nonisolated private static func detectPitch(samples: [Float], sampleRate: Double) -> Double? {
        guard samples.count >= 1024 else { return nil }
        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
        guard rms > 0.008 else { return nil }

        let minLag = max(2, Int(sampleRate / 1000))
        let maxLag = min(samples.count / 2, Int(sampleRate / 65))
        guard minLag < maxLag else { return nil }
        var bestLag = 0
        var bestCorrelation = -Double.infinity
        for lag in minLag...maxLag {
            var correlation = 0.0
            for i in 0..<(samples.count - lag) {
                correlation += Double(samples[i]) * Double(samples[i + lag])
            }
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }
        guard bestLag > 0 else { return nil }
        let frequency = sampleRate / Double(bestLag)
        return (65...1000).contains(frequency) ? frequency : nil
    }
}
