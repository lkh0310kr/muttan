import AVFoundation
import SwiftUI

struct PracticeEvent: Decodable, Identifiable, Hashable {
    let id: String
    let bar: Int
    let beat: Int
    let durationBeats: Int
    let midi: Int
    let string: Int
    let fret: Int
    let label: String

    var absoluteBeat: Int { (bar - 1) * 4 + beat }
}

struct PracticeTrack: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tempo: Int
    let loop: Bool
    let notes: [PracticeEvent]
    let key: String?
}

private struct PracticeCatalogFile: Decodable {
    let exercises: [PracticeTrack]
    let songs: [PracticeTrack]
}

enum PracticeCatalog {
    private static let catalog: PracticeCatalogFile = {
        guard let url = Bundle.main.url(forResource: "practice-content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(PracticeCatalogFile.self, from: data) else {
            fatalError("practice-content.json is missing or invalid")
        }
        return catalog
    }()
    static var exercises: [PracticeTrack] { catalog.exercises }
    static var songs: [PracticeTrack] { catalog.songs }
}

struct PracticeLibraryView: View {
    var snapshotMode = false
    var isActive = true
    private var exercise: PracticeTrack { PracticeCatalog.exercises[0] }

    var body: some View {
        NavigationStack {
            if snapshotMode {
                PracticePlayerView(track: exercise, mode: .exercise, isActive: isActive, snapshotMode: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("짧은 연습부터 차근차근")
                            .font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink {
                            PracticePlayerView(track: exercise, mode: .exercise, isActive: isActive)
                        } label: {
                            PracticeTrackCard(track: exercise, symbol: "hand.tap", tag: "리듬 연습")
                        }
                        .buttonStyle(.plain)
                        Text("현과 프렛을 차례로 누르며 소리를 맞춰 보세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("연습")
                .toolbarTitleDisplayMode(.large)
            }
        }
    }
}

struct SongLibraryView: View {
    var snapshotMode = false
    var isActive = true
    private var song: PracticeTrack { PracticeCatalog.songs[0] }

    var body: some View {
        NavigationStack {
            if snapshotMode {
                PracticePlayerView(track: song, mode: .song, isActive: isActive, snapshotMode: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("아는 노래를 한 음씩 따라 쳐요")
                            .font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink {
                            PracticePlayerView(track: song, mode: .song, isActive: isActive)
                        } label: {
                            PracticeTrackCard(track: song, symbol: "music.note", tag: "멜로디")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("곡")
                .toolbarTitleDisplayMode(.large)
            }
        }
    }
}

private struct PracticeTrackCard: View {
    let track: PracticeTrack
    let symbol: String
    let tag: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Color.instrumentAccent)
                .frame(width: 58, height: 58)
                .background(Color.instrumentAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title).font(.headline).foregroundStyle(.primary)
                Text(track.subtitle).font(.subheadline).foregroundStyle(.secondary)
                Text(tag).font(.caption.weight(.medium)).foregroundStyle(Color.instrumentAccent)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

private enum PlayerMode {
    case exercise
    case song
}

private enum PlayerStatus: Equatable {
    case ready
    case countingIn
    case listening
    case paused
    case permissionDenied
    case failed(String)
    case complete
}

@MainActor
private final class PracticeSession: ObservableObject {
    @Published private(set) var status: PlayerStatus = .ready
    @Published private(set) var currentIndex = 0
    @Published private(set) var heardMidi: Double?
    @Published private(set) var message: String?
    @Published private(set) var countInValue = 2

    private let track: PracticeTrack
    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.muttan.practice-analysis", qos: .userInitiated)
    private var tapInstalled = false
    private var attempt = 0
    private var isRequestingPermission = false
    private var countInTask: Task<Void, Never>?
    private var targetStart: TimeInterval?
    private var onsetTime: TimeInterval?
    private var candidateSamples = 0
    private var mismatchSamples = 0
    private var processingPermit = DispatchSemaphore(value: 1)

    init(track: PracticeTrack) { self.track = track }

    var currentEvent: PracticeEvent { track.notes[min(currentIndex, track.notes.count - 1)] }
    var progress: Double { track.notes.isEmpty ? 0 : Double(currentIndex) / Double(track.notes.count) }

    func start() {
        guard !isRequestingPermission else { return }
        guard status == .ready || status == .paused || status == .permissionDenied || isFailed else { return }
        attempt += 1
        let thisAttempt = attempt
        isRequestingPermission = true
        message = nil
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, self.attempt == thisAttempt else { return }
                self.isRequestingPermission = false
                guard granted else {
                    self.status = .permissionDenied
                    self.message = "마이크 접근을 허용하면 연주를 인식할 수 있어요."
                    return
                }
                self.startAudio()
            }
        }
    }

    func pause() {
        pause(reason: "멈췄어요. 준비되면 다시 시작하세요.")
    }

    func pause(reason: String) {
        guard isRequestingPermission || status == .listening || status == .countingIn else { return }
        attempt += 1
        isRequestingPermission = false
        countInTask?.cancel()
        stopAudio()
        status = .paused
        message = reason
    }

    func restart() {
        attempt += 1
        countInTask?.cancel()
        stopAudio()
        currentIndex = 0
        heardMidi = nil
        status = .ready
        message = nil
    }

    func skipCurrent() {
        guard status == .listening else { return }
        let now = ProcessInfo.processInfo.systemUptime
        advance()
        targetStart = now + 60.0 / Double(track.tempo)
    }

    private func startAudio() {
        do {
            if engine.isRunning { engine.stop() }
            removeTap()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "PracticeAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "입력 장치를 찾을 수 없어요."])
            }
            let sampleRate = format.sampleRate
            let queue = analysisQueue
            let permit = processingPermit
            var sampleWindow: [Float] = []
            var previousRMS = 0.0
            var lastOnsetAt = 0.0
            var previousFrequency: Double?
            var lastPitchChangeAt = 0.0
            var frameCounter = 0
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee,
                      permit.wait(timeout: .now()) == .success else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let count = Int(buffer.frameLength)
                let chunk = Array(UnsafeBufferPointer(start: channel, count: count))
                let rms = sqrt(chunk.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(max(count, 1)))
                let onset = rms > 0.006 && (previousRMS < 0.004 || rms > previousRMS * 1.7) && now - lastOnsetAt > 0.12
                if onset { lastOnsetAt = now }
                previousRMS = rms
                sampleWindow.append(contentsOf: chunk)
                if sampleWindow.count > 2048 { sampleWindow.removeFirst(sampleWindow.count - 2048) }
                frameCounter += 1
                guard onset || frameCounter.isMultiple(of: 2) else {
                    permit.signal()
                    return
                }
                let samples = sampleWindow
                queue.async {
                    let estimate = samples.count >= 2048 ? PitchDetector.estimate(samples: samples, sampleRate: sampleRate) : nil
                    var detectedOnset = onset
                    if let estimate {
                        if let previousFrequency,
                           abs(12 * log2(estimate.frequency / previousFrequency)) >= 0.8,
                           now - lastPitchChangeAt > 0.12 {
                            detectedOnset = true
                            lastPitchChangeAt = now
                        }
                        previousFrequency = estimate.frequency
                    }
                    Task { @MainActor in
                        defer { permit.signal() }
                        self?.consume(estimate, onset: detectedOnset, capturedAt: now)
                    }
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            status = .countingIn
            countInValue = 2
            beginCountIn()
            DebugLog.record("practice.audio.started", details: ["sampleRate": String(sampleRate)])
        } catch {
            stopAudio()
            status = .failed(error.localizedDescription)
            message = "마이크를 시작할 수 없어요. 다시 시도해 주세요."
            DebugLog.record("practice.audio.start_failed", details: ["error": error.localizedDescription], level: .error)
        }
    }

    private func beginCountIn() {
        countInTask?.cancel()
        let secondsPerBeat = 60.0 / Double(track.tempo)
        countInTask = Task { [weak self] in
            guard let self else { return }
            for beat in stride(from: 2, through: 1, by: -1) {
                self.countInValue = beat
                do { try await Task.sleep(for: .seconds(secondsPerBeat)) }
                catch { return }
            }
            self.countInValue = 0
            self.targetStart = ProcessInfo.processInfo.systemUptime
            self.status = .listening
            self.message = nil
        }
    }

    private func consume(_ estimate: PitchEstimate?, onset: Bool, capturedAt: TimeInterval) {
        guard status == .listening || status == .countingIn else { return }
        guard let estimate else { return }
        let detectedMidi = 69 + 12 * log2(estimate.frequency / 440)
        if heardMidi.map({ Int($0.rounded()) != Int(detectedMidi.rounded()) }) ?? true {
            heardMidi = detectedMidi
        }
        guard status == .listening else { return }
        if onset {
            onsetTime = capturedAt
            candidateSamples = 0
            mismatchSamples = 0
        }
        guard let onsetTime, capturedAt - onsetTime <= 0.28 else { return }
        guard let targetStart else { return }
        let beatDuration = 60.0 / Double(track.tempo)
        let timingWindow = beatDuration * 0.35
        if onsetTime < targetStart - timingWindow {
            self.onsetTime = nil
            return
        }
        if onsetTime > targetStart + timingWindow {
            message = "박자를 놓쳤어요. 계속을 눌러 다음 음으로 갈 수 있어요."
            self.onsetTime = nil
            return
        }
        let expected = Double(currentEvent.midi)
        if abs(detectedMidi - expected) <= 0.5 {
            candidateSamples += 1
            mismatchSamples = 0
            if candidateSamples >= 2 {
                message = "맞았어요"
                advance()
                self.onsetTime = nil
            }
        } else if capturedAt - onsetTime >= 0.08 {
            mismatchSamples += 1
            if mismatchSamples >= 4 {
                retry(from: onsetTime)
                self.onsetTime = nil
            }
        }
    }

    private func advance() {
        let nextStart = (targetStart ?? ProcessInfo.processInfo.systemUptime) + Double(currentEvent.durationBeats) * 60.0 / Double(track.tempo)
        if currentIndex + 1 < track.notes.count {
            currentIndex += 1
        } else if track.loop {
            currentIndex = 0
        } else {
            stopAudio()
            status = .complete
            message = "끝까지 연주했어요"
            return
        }
        targetStart = nextStart
        candidateSamples = 0
        mismatchSamples = 0
        onsetTime = nil
    }

    private func retry(from time: TimeInterval) {
        let rewind = 1.5
        let index = currentIndex
        let target = track.notes[index]
        var rewindIndex = index
        while rewindIndex > 0 {
            let previous = track.notes[rewindIndex - 1]
            let distance = Double(target.absoluteBeat - previous.absoluteBeat) * 60 / Double(track.tempo)
            guard distance <= rewind else { break }
            rewindIndex -= 1
        }
        currentIndex = rewindIndex
        message = "다시 들어볼게요"
        candidateSamples = 0
        mismatchSamples = 0
        onsetTime = nil
        status = .countingIn
        countInValue = 2
        beginCountIn()
        DebugLog.record("practice.retry", details: ["from": String(index), "to": String(currentIndex), "at": String(time)])
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        removeTap()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeTap() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }
}

private struct PracticePlayerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var session: PracticeSession
    private let track: PracticeTrack
    private let mode: PlayerMode
    private let snapshotMode: Bool
    private let isActive: Bool

    init(track: PracticeTrack, mode: PlayerMode, isActive: Bool = true, snapshotMode: Bool = false) {
        self.track = track
        self.mode = mode
        self.isActive = isActive
        self.snapshotMode = snapshotMode
        _session = StateObject(wrappedValue: PracticeSession(track: track))
    }

    private var current: PracticeEvent { track.notes[min(session.currentIndex, track.notes.count - 1)] }
    private var nextEvents: ArraySlice<PracticeEvent> {
        let start = min(session.currentIndex, track.notes.count)
        let end = min(start + 4, track.notes.count)
        return track.notes[start..<end]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 28) {
                    if mode == .exercise { exerciseScore } else { songScore }
                    statusPanel
                    controls
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text(track.title).font(.headline) } }
        .onDisappear { if !snapshotMode { session.pause() } }
        .onChange(of: isActive) { _, active in
            guard !active, !snapshotMode else { return }
            session.pause(reason: "다른 화면으로 이동했어요. 다시 시작을 눌러 주세요.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, !snapshotMode { session.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard !snapshotMode,
                  let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            session.pause(reason: "오디오가 중단됐어요. 다시 시작해 주세요.")
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            guard !snapshotMode,
                  let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            session.pause(reason: "입력 장치 연결이 끊겼어요. 다시 시작해 주세요.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .exercise ? "연습" : "곡").font(.caption).foregroundStyle(.secondary)
                Text(track.subtitle).font(.subheadline.weight(.medium))
            }
            Spacer()
            Label("분당 \(track.tempo)박", systemImage: "metronome")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var exerciseScore: some View {
        VStack(spacing: 22) {
            Text("\(current.string)번 현")
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 4) {
                    Text(current.label).font(.system(size: 54, weight: .semibold, design: .rounded))
                    Text(current.fret == 0 ? "개방현" : "\(current.fret)프렛")
                        .font(.headline).foregroundStyle(.secondary)
                }
                Image(systemName: "arrow.right")
                    .font(.title3).foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(nextEvents.prefix(4)) { event in
                        HStack(spacing: 9) {
                            Text("\(event.string)번")
                                .font(.caption).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                            Text("\(event.fret)")
                                .font(.system(.title3, design: .rounded, weight: .medium))
                                .foregroundStyle(event.id == current.id ? Color.instrumentAccent : Color.primary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            beatDots
        }
    }

    private var songScore: some View {
        VStack(spacing: 22) {
            HStack {
                Text("마디 \(current.bar)")
                Spacer()
                Text("\(current.beat + 1)박")
            }
            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            StaffTablature(events: Array(nextEvents), currentID: current.id)
                .frame(height: 204)
                .padding(18)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 12) {
                Text(current.label).font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("\(current.string)번 현 · \(current.fret)프렛")
                    .font(.headline).foregroundStyle(.secondary)
            }
        }
    }

    private var beatDots: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == current.beat ? Color.instrumentAccent : Color.secondary.opacity(0.2))
                    .frame(width: index == current.beat ? 16 : 10, height: index == current.beat ? 16 : 10)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 35)
        .accessibilityLabel("현재 \(current.beat + 1)박")
    }

    private var statusPanel: some View {
        VStack(spacing: 10) {
            if session.status == .countingIn {
                Text(session.countInValue == 0 ? "시작" : "\(session.countInValue)")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
            } else if let heard = session.heardMidi, session.status == .listening {
                Text(TunerPitchReading(midi: heard).noteName)
                    .font(.system(size: 31, weight: .medium, design: .rounded))
            } else {
                Image(systemName: statusSymbol)
                    .font(.title2).foregroundStyle(session.status == .permissionDenied ? .orange : Color.instrumentAccent)
            }
            Text(session.message ?? statusDescription)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            ProgressView(value: session.progress)
                .tint(Color.instrumentAccent)
            Text("\(min(session.currentIndex + 1, track.notes.count)) / \(track.notes.count)")
                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        switch session.status {
        case .ready: "mic"
        case .countingIn: "metronome"
        case .listening: "waveform"
        case .paused: "pause.fill"
        case .permissionDenied: "mic.slash"
        case .failed: "exclamationmark.triangle"
        case .complete: "checkmark.circle"
        }
    }

    private var statusDescription: String {
        switch session.status {
        case .ready: "기타를 준비하고 시작을 누르세요"
        case .countingIn: "박자에 맞춰 준비하세요"
        case .listening: "현재 음을 연주하세요"
        case .paused: "잠시 멈췄어요"
        case .permissionDenied: "마이크 권한이 필요해요"
        case .failed: "오디오 입력을 시작할 수 없어요"
        case .complete: "처음부터 다시 연주할 수 있어요"
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if session.status == .permissionDenied {
                Button("설정 열기") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.bordered)
            }
            if session.status == .ready || session.status == .paused || session.status == .permissionDenied || isFailure {
                Button(session.status == .ready ? "연습 시작" : "다시 시작") { session.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.instrumentAccent)
                    .disabled(snapshotMode)
            } else if session.status == .listening || session.status == .countingIn {
                Button("일시 정지") { session.pause() }.buttonStyle(.bordered)
                Button("계속") { session.skipCurrent() }.buttonStyle(.bordered)
            } else if session.status == .complete {
                Button("처음부터") { session.restart() }.buttonStyle(.borderedProminent).tint(Color.instrumentAccent)
            }
            if session.currentIndex > 0, session.status != .complete {
                Button("처음부터") { session.restart() }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var isFailure: Bool {
        if case .failed = session.status { return true }
        return false
    }
}

private struct StaffTablature: View {
    let events: [PracticeEvent]
    let currentID: String

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let top = geometry.size.height * 0.33
            let spacing = geometry.size.height * 0.075
            let bottom = top + spacing * 4
            ZStack(alignment: .topLeading) {
                ForEach(0..<5, id: \.self) { line in
                    Path { path in
                        let y = top + CGFloat(line) * spacing
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                }
                Text("𝄞")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .position(x: 20, y: top + spacing * 2)
                ForEach(0..<events.count, id: \.self) { index in
                    let event = events[index]
                    let x = 58 + CGFloat(index) * max(48, (width - 80) / CGFloat(max(events.count - 1, 1)))
                    let step = staffStep(for: event)
                    let y = bottom - CGFloat(step) * spacing / 2
                    if step <= -2, step.isMultiple(of: 2) {
                        Path { path in
                            path.move(to: CGPoint(x: x - 15, y: y))
                            path.addLine(to: CGPoint(x: x + 15, y: y))
                        }
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                    }
                    Text(event.label)
                        .font(.system(.headline, design: .rounded, weight: .medium))
                        .foregroundStyle(event.id == currentID ? Color.instrumentAccent : Color.primary)
                        .padding(.horizontal, 4)
                        .background(event.id == currentID ? Color.instrumentAccent.opacity(0.16) : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .position(x: x, y: y)
                    Text("\(event.string)·\(event.fret)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(event.id == currentID ? Color.instrumentAccent : .secondary)
                        .position(x: x, y: top + spacing * 6)
                }
            }
        }
        .accessibilityLabel("오선 악보와 기타 타브")
    }

    private func staffStep(for event: PracticeEvent) -> Int {
        let letter = event.label.first ?? "E"
        let octave = event.label.last?.wholeNumberValue ?? 4
        let diatonicIndex = ["C", "D", "E", "F", "G", "A", "B"].firstIndex(of: String(letter)) ?? 2
        return octave * 7 + diatonicIndex - 30 // E4 is the bottom line of treble clef.
    }
}
