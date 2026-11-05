import AVFoundation
import SwiftUI

struct TunerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    var screenshotMode = false
    @StateObject private var tuner = GuitarTuner()
    @AppStorage("muttan.tuner.tuning") private var tuningRawValue = GuitarTuning.standard.rawValue
    @AppStorage("muttan.tuner.string") private var stringRawValue = "auto"

    private var tuning: GuitarTuning { screenshotMode ? .standard : (GuitarTuning(rawValue: tuningRawValue) ?? .standard) }
    private var selectedString: GuitarString? { screenshotMode ? nil : GuitarString(rawValue: stringRawValue) }
    private var activeString: GuitarString? {
        selectedString ?? displayedMIDINote.flatMap { tuning.nearestString(to: $0) }
    }
    private var targetMIDINote: Int? { activeString.map { tuning.midi(for: $0) } }
    private var targetDescription: String {
        guard let string = activeString, let midi = targetMIDINote else { return "PLAY AN OPEN STRING" }
        let target = TunerPitchReading(midi: Double(midi))
        return String(format: "STRING %d · %@ · %.1f Hz", string.number, target.noteName, target.frequency)
    }
    private var displayedMIDINote: Double? { screenshotMode ? 40 : tuner.midi }
    private var displayedNoteName: String? { screenshotMode ? "E2" : tuner.noteName }
    private var displayedFrequency: Double? { screenshotMode ? 82.4 : tuner.frequency }
    private var deviation: Double? {
        guard let midi = displayedMIDINote, let target = targetMIDINote else { return nil }
        return (midi - Double(target)) * 100
    }
    private var isInTune: Bool { deviation.map { abs($0) <= 4 } ?? false }
    private var autoBinding: Binding<Bool> {
        Binding(
            get: { selectedString == nil },
            set: { stringRawValue = $0 ? "auto" : (selectedString?.rawValue ?? activeString?.rawValue ?? GuitarString.lowE.rawValue) }
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    tuningHeader
                        .padding(.top, 8)

                    TuningPitchGraph(
                        target: targetDescription,
                        noteName: displayedNoteName,
                        cents: deviation,
                        frequency: displayedFrequency,
                        feedback: feedbackText,
                        isInTune: isInTune
                    )
                    .frame(height: min(max(geometry.size.height * 0.31, 190), 250))

                    HeadstockStringPicker(
                        tuning: tuning,
                        selectedString: activeString,
                        onSelect: { stringRawValue = $0.rawValue }
                    )
                    .frame(height: min(max(geometry.size.height * 0.41, 250), 330))
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    tunerButton
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(screenBackground.ignoresSafeArea())
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { DebugLog.record("screen.tuner.appear") }
            .onDisappear { tuner.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { tuner.pause(reason: "Tuner paused. Tap Start to resume.") }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
                tuner.pause(reason: "Audio interrupted. Tap Start to resume.")
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
                if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    tuner.pause(reason: "Audio input disconnected. Tap Start to resume.")
                }
            }
            .sensoryFeedback(.success, trigger: isInTune) { _, newValue in newValue }
        }
    }

    private var screenBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.08, blue: 0.095)
            : Color(uiColor: .systemBackground)
    }

    private var tuningHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Menu {
                Picker("Guitar tuning", selection: $tuningRawValue) {
                    ForEach(GuitarTuning.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Guitar 6-string")
                            .font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    Text(tuning.title)
                        .font(.subheadline)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Guitar 6-string, \(tuning.title). Choose tuning")

            Spacer(minLength: 8)

            Toggle(isOn: autoBinding) {
                Text("AUTO")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
            }
            .toggleStyle(.switch)
            .tint(.mint)
            .fixedSize()
            .accessibilityLabel("Automatic string detection")
        }
        .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
        .frame(height: 58)
    }

    private var feedbackText: String {
        if screenshotMode { return "In tune" }
        if let statusMessage = tuner.statusMessage { return statusMessage }
        guard tuner.isListening else { return "Pluck a string to tune" }
        guard let deviation else { return displayedMIDINote == nil ? "Listening for a clear note…" : "Play an open guitar string" }
        if abs(deviation) <= 4 { return "In tune" }
        return deviation < 0 ? (abs(deviation) > 50 ? "Tune up" : "Tune up slightly") : (abs(deviation) > 50 ? "Tune down" : "Tune down slightly")
    }

    private var tunerButton: some View {
        Button {
            tuner.isListening ? tuner.stop() : tuner.start()
        } label: {
            Label(
                screenshotMode ? "Preview mode" : (tuner.isListening ? "Stop tuner" : (tuner.isStarting ? "Starting…" : "Start tuner")),
                systemImage: screenshotMode ? "waveform" : (tuner.isListening ? "stop.fill" : "mic.fill")
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Color.black.opacity(0.88))
        }
        .buttonStyle(.plain)
        .disabled(tuner.isStarting)
        .allowsHitTesting(!screenshotMode)
    }
}

private struct TuningPitchGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let target: String
    let noteName: String?
    let cents: Double?
    let frequency: Double?
    let feedback: String
    let isInTune: Bool

    var body: some View {
        GeometryReader { geometry in
            let center = geometry.size.width / 2
            let normalized = CGFloat(max(-50, min(50, cents ?? 0)) / 50)
            ZStack {
                Canvas { context, size in
                    var grid = Path()
                    for index in 0...24 {
                        let x = size.width * CGFloat(index) / 24
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for index in 0...10 {
                        let y = size.height * CGFloat(index) / 10
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.07)), lineWidth: 1)

                    var reference = Path()
                    reference.move(to: CGPoint(x: center, y: 0))
                    reference.addLine(to: CGPoint(x: center, y: size.height))
                    context.stroke(reference, with: .color(.mint.opacity(0.9)), lineWidth: 1.5)
                }

                Text(target)
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
                HStack {
                    Text("♭")
                    Spacer()
                    Text("♯")
                }
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .position(x: center, y: geometry.size.height * 0.48)

                VStack(spacing: 5) {
                    if isInTune {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.mint)
                            .frame(width: 38, height: 38)
                            .background(colorScheme == .dark ? Color(red: 0.075, green: 0.08, blue: 0.095) : Color(uiColor: .systemBackground), in: Circle())
                            .overlay(Circle().stroke(.mint, lineWidth: 2))
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(noteName ?? "—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(noteName == nil ? Color.secondary : (colorScheme == .dark ? Color.mint : Color.primary))
                        .frame(minWidth: 54, minHeight: 42)
                        .background(colorScheme == .dark ? Color(red: 0.105, green: 0.115, blue: 0.135) : Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                }
                .position(x: center + normalized * (center - 42), y: geometry.size.height * 0.40)
                .animation(.snappy(duration: 0.16), value: cents)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isInTune)

                VStack(spacing: 4) {
                    if let cents {
                        Text(String(format: "%+.0f cents", abs(cents) < 0.5 ? 0 : cents))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit().foregroundStyle(isInTune ? Color.mint : Color.primary)
                    }
                    Text(feedback.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.9)
                        .foregroundStyle(isInTune ? Color.mint : (colorScheme == .dark ? Color.white.opacity(0.8) : Color.primary.opacity(0.8)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(frequency.map { String(format: "%.1f Hz", $0) } ?? " ")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 12)
            }
            .clipped()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(graphAccessibilityLabel)
        }
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var graphAccessibilityLabel: String {
        guard let cents else { return "Tuner. \(feedback)" }
        return String(format: "%@, %.0f cents %@. %@", noteName ?? "No note", abs(cents), cents < 0 ? "flat" : "sharp", feedback)
    }
}

private struct HeadstockStringPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    let tuning: GuitarTuning
    let selectedString: GuitarString?
    let onSelect: (GuitarString) -> Void

    private let leftStrings: [GuitarString] = [.d, .a, .lowE]
    private let rightStrings: [GuitarString] = [.g, .b, .highE]

    var body: some View {
        HStack(spacing: 2) {
            stringColumn(leftStrings)
            GuitarHeadstock()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            stringColumn(rightStrings)
        }
        .padding(.vertical, 4)
    }

    private func stringColumn(_ strings: [GuitarString]) -> some View {
        VStack(spacing: 14) {
            ForEach(strings) { string in
                let midi = tuning.midi(for: string)
                Button {
                    onSelect(string)
                } label: {
                    VStack(spacing: 3) {
                        Text(Self.noteName(for: midi))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("\(string.number)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.56) : Color.secondary)
                    }
                    .foregroundStyle(selectedString == string ? Color.mint : (colorScheme == .dark ? Color.white : Color.primary))
                    .frame(width: 56, height: 56)
                    .background {
                        Circle().fill(selectedString == string ? Color.mint.opacity(0.12) : Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.04))
                    }
                    .overlay {
                        Circle().stroke(selectedString == string ? Color.mint : Color.primary.opacity(0.22), lineWidth: selectedString == string ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("String \(string.number), \(Self.noteName(for: midi))")
                .accessibilityAddTraits(selectedString == string ? .isSelected : [])
            }
        }
        .frame(width: 60)
    }

    private static func noteName(for midi: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let index = (midi % 12 + 12) % 12
        return "\(names[index])\(midi / 12 - 1)"
    }
}

private struct GuitarHeadstock: View {
    private let pegPositions: [(CGFloat, CGFloat)] = [
        (0.13, 0.30), (0.13, 0.48), (0.15, 0.66),
        (0.87, 0.30), (0.87, 0.48), (0.85, 0.66)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                HeadstockShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.34, green: 0.19, blue: 0.12), Color(red: 0.18, green: 0.105, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                HeadstockShape()
                    .stroke(Color(red: 0.78, green: 0.57, blue: 0.35).opacity(0.72), lineWidth: 2)

                Canvas { context, canvasSize in
                    var strings = Path()
                    let anchorPositions: [CGFloat] = [0.39, 0.435, 0.48, 0.52, 0.565, 0.61]
                    for index in 0..<6 {
                        let peg = pegPositions[index]
                        strings.move(to: CGPoint(x: canvasSize.width * anchorPositions[index], y: canvasSize.height * 0.94))
                        strings.addLine(to: CGPoint(x: canvasSize.width * peg.0, y: canvasSize.height * peg.1))
                    }
                    context.stroke(strings, with: .color(.white.opacity(0.62)), lineWidth: 1.2)
                }

                ForEach(pegPositions.indices, id: \.self) { index in
                    let position = pegPositions[index]
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.white, Color(white: 0.52), .white.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Circle().stroke(Color.black.opacity(0.5), lineWidth: 1)
                        Circle().fill(Color(white: 0.3)).frame(width: 5, height: 5)
                    }
                    .frame(width: 19, height: 19)
                    .position(x: size.width * position.0, y: size.height * position.1)
                }

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.82, green: 0.73, blue: 0.56))
                    .frame(width: size.width * 0.34, height: 5)
                    .position(x: size.width / 2, y: size.height * 0.94)

                Text("muttan")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .position(x: size.width / 2, y: size.height * 0.22)
            }
        }
        .frame(maxWidth: 210)
        .aspectRatio(0.66, contentMode: .fit)
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

private struct HeadstockShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.44, y: h * 0.02))
        path.addCurve(to: CGPoint(x: w * 0.19, y: h * 0.13), control1: CGPoint(x: w * 0.30, y: h * -0.01), control2: CGPoint(x: w * 0.23, y: h * 0.02))
        path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.26), control1: CGPoint(x: w * 0.02, y: h * 0.17), control2: CGPoint(x: w * 0.02, y: h * 0.22))
        path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.42), control1: CGPoint(x: w * 0.02, y: h * 0.30), control2: CGPoint(x: w * 0.03, y: h * 0.36))
        path.addCurve(to: CGPoint(x: w * 0.15, y: h * 0.58), control1: CGPoint(x: w * 0.02, y: h * 0.47), control2: CGPoint(x: w * 0.05, y: h * 0.53))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.97))
        path.addCurve(to: CGPoint(x: w * 0.66, y: h * 0.97), control1: CGPoint(x: w * 0.43, y: h), control2: CGPoint(x: w * 0.57, y: h))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.58))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.42), control1: CGPoint(x: w * 0.95, y: h * 0.53), control2: CGPoint(x: w * 0.98, y: h * 0.47))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.26), control1: CGPoint(x: w * 0.97, y: h * 0.36), control2: CGPoint(x: w * 0.98, y: h * 0.30))
        path.addCurve(to: CGPoint(x: w * 0.81, y: h * 0.13), control1: CGPoint(x: w * 0.98, y: h * 0.22), control2: CGPoint(x: w * 0.98, y: h * 0.17))
        path.addCurve(to: CGPoint(x: w * 0.56, y: h * 0.02), control1: CGPoint(x: w * 0.77, y: h * 0.02), control2: CGPoint(x: w * 0.70, y: h * -0.01))
        path.closeSubpath()
        return path
    }
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
    @Published private(set) var midi: Double?
    @Published private(set) var noteName: String?
    @Published private(set) var isListening = false
    @Published private(set) var isStarting = false
    @Published private(set) var statusMessage: String?

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.muttan.pitch-analysis", qos: .userInitiated)
    private let noPitchLogGate = AudioLogGate()
    private var signal = TunerSignalState()
    private var expiryTask: Task<Void, Never>?
    private var lastPitchLog = Date.distantPast
    private var tapInstalled = false
    private var startAttempt = 0

    func start() {
        guard !isListening, !isStarting else {
            DebugLog.record("tuner.start.ignored", details: ["isListening": String(isListening), "isStarting": String(isStarting)])
            return
        }
        isStarting = true
        startAttempt += 1
        let attempt = startAttempt
        statusMessage = nil
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
                    self.statusMessage = "Microphone access is required. Enable it in Settings."
                    return
                }
                self.startEngine()
            }
        }
    }

    func pause(reason: String) {
        guard isListening || isStarting else { return }
        stop()
        statusMessage = reason
        DebugLog.record("tuner.paused", details: ["reason": reason])
    }

    func stop() {
        startAttempt += 1
        isStarting = false
        signal.stop()
        expiryTask?.cancel()
        expiryTask = nil
        publishReading()
        statusMessage = nil
        guard isListening || engine.isRunning || tapInstalled else { return }
        DebugLog.record("tuner.stop", details: ["engineRunning": String(engine.isRunning)])
        removeInputTapIfNeeded()
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
    }

    private func startEngine() {
        defer { isStarting = false }
        do {
            if engine.isRunning { engine.stop() }
            removeInputTapIfNeeded()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else {
                DebugLog.record("tuner.audio.no_input", details: ["sampleRate": String(format.sampleRate)])
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                statusMessage = "Microphone input is unavailable."
                return
            }
            DebugLog.record("tuner.audio.format", details: [
                "sampleRate": String(format.sampleRate),
                "channels": String(format.channelCount),
                "bufferFrames": "4096"
            ])

            let noPitchLogGate = self.noPitchLogGate
            let analysisQueue = self.analysisQueue
            let sampleRate = format.sampleRate
            let token = signal.start()
            // Each session has its own permit. Never wait or queue extra work on the audio callback.
            let permit = DispatchSemaphore(value: 1)
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?.pointee, permit.wait(timeout: .now()) == .success else { return }
                let capturedAt = ProcessInfo.processInfo.systemUptime
                let count = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channel, count: count))
                analysisQueue.async {
                    let estimate = PitchDetector.estimate(samples: samples, sampleRate: sampleRate)
                    if estimate == nil, noPitchLogGate.shouldLog(interval: 5) {
                        DebugLog.record("tuner.audio.no_pitch", details: ["frames": String(count)])
                    }
                    Task { @MainActor in
                        defer { permit.signal() }
                        self?.update(with: estimate, capturedAt: capturedAt, session: token)
                    }
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            isListening = true
            expiryTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(200)) }
                    catch { return }
                    guard let self, !Task.isCancelled else { return }
                    self.signal.expire(at: ProcessInfo.processInfo.systemUptime)
                    self.publishReading()
                }
            }
            DebugLog.record("tuner.audio.started")
        } catch {
            stop()
            statusMessage = error.localizedDescription
            DebugLog.record("tuner.audio.start_failed", details: ["error": error.localizedDescription], level: .error)
        }
    }

    private func removeInputTapIfNeeded() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
        DebugLog.record("tuner.audio.tap_removed")
    }

    private func publishReading() {
        midi = signal.reading?.midi
        frequency = signal.reading?.frequency
        noteName = signal.reading?.noteName
    }

    private func update(with estimate: PitchEstimate?, capturedAt: TimeInterval, session token: Int) {
        guard isListening, token == signal.session else { return }
        signal.consume(estimate, capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime, session: token)
        publishReading()
        if let estimate, noteName != nil, Date().timeIntervalSince(lastPitchLog) >= 1 {
            lastPitchLog = Date()
            DebugLog.record("tuner.pitch", details: [
                "frequencyHz": String(format: "%.2f", estimate.frequency),
                "note": noteName ?? "unknown",
                "clarity": String(format: "%.2f", estimate.clarity)
            ])
        }
    }
}
