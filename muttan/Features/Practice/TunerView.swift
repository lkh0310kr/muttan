import AVFoundation
import SwiftUI

struct TunerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var isVisible = false
    @State private var manualString: GuitarString?
    var screenshotMode = false
    @StateObject private var tuner = GuitarTuner()
    @AppStorage("muttan.tuner.tuning") private var tuningRawValue = GuitarTuning.standard.rawValue

    private var tuning: GuitarTuning { screenshotMode ? .standard : (GuitarTuning(rawValue: tuningRawValue) ?? .standard) }
    private var selectedString: GuitarString? { screenshotMode ? nil : manualString }
    private var activeString: GuitarString? {
        selectedString ?? displayedMIDINote.flatMap { tuning.nearestString(to: $0) }
    }
    private var targetMIDINote: Int? { activeString.map { tuning.midi(for: $0) } }
    private var displayedMIDINote: Double? { screenshotMode ? 40 : tuner.midi }
    private var displayedNoteName: String? { displayedMIDINote.map { TunerPitchReading(midi: $0).pitchClassName } }
    private var deviation: Double? {
        guard let midi = displayedMIDINote, let target = targetMIDINote else { return nil }
        return (midi - Double(target)) * 100
    }
    private var isInTune: Bool { deviation.map { abs($0) <= 4 } ?? false }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let pitchHeight = min(190, geometry.size.height * 0.28)
                let errorHeight: CGFloat = tuner.statusMessage == nil ? 0 : 86
                let instrumentHeight = min(380, max(0, geometry.size.height - pitchHeight - 100 - errorHeight))
                VStack(spacing: 0) {
                    tuningHeader.padding(.top, 8)
                    Spacer(minLength: 16)
                    TuningPitchGraph(noteName: displayedNoteName, cents: deviation,
                                     feedback: feedbackText, isInTune: isInTune)
                        .frame(height: pitchHeight)
                    HeadstockStringPicker(
                        tuning: tuning,
                        selectedString: activeString,
                        lockedString: selectedString,
                        onSelect: { manualString = manualString == $0 ? nil : $0 }
                    )
                    .frame(height: instrumentHeight)
                    Spacer(minLength: 16)
                    if let message = tuner.statusMessage, !screenshotMode {
                        VStack(spacing: 8) {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(tuner.permissionDenied ? "마이크 설정 열기" : "다시 듣기") {
                                if tuner.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                } else { tuner.start() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(screenBackground.ignoresSafeArea())
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isVisible = true
                manualString = nil
                DebugLog.record("screen.tuner.appear")
                if !screenshotMode { tuner.start() }
            }
            .onDisappear { isVisible = false; tuner.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { tuner.stop() }
                if phase == .active, isVisible, !screenshotMode { tuner.start() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
                if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   type == AVAudioSession.InterruptionType.began.rawValue {
                    tuner.pause(reason: "오디오가 중단됐어요. 다시 들어 주세요.")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
                if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    tuner.pause(reason: "입력 장치 연결이 끊겼어요. 다시 시작해 주세요.")
                }
            }
            .sensoryFeedback(.success, trigger: isInTune) { _, newValue in newValue }
        }
    }

    private var screenBackground: Color { .tunerSurface }

    private var tuningHeader: some View {
        HStack {
            Menu {
                Picker("튜닝", selection: $tuningRawValue) {
                    ForEach(GuitarTuning.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(tuning.title).font(.headline)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tuning.title), 튜닝 선택")
            Spacer()
        }
    }

    private var feedbackText: String {
        if screenshotMode { return "음정이 맞아요" }
        if let statusMessage = tuner.statusMessage { return statusMessage }
        guard tuner.isListening else { return "기타 소리를 기다리고 있어요" }
        guard let deviation else { return displayedMIDINote == nil ? "기타 소리를 듣고 있어요" : "개방현을 연주하세요" }
        if abs(deviation) <= 4 { return "음정이 맞아요" }
        return deviation < 0 ? (abs(deviation) > 50 ? "음정을 높이세요" : "음정을 조금 높이세요") : (abs(deviation) > 50 ? "음정을 낮추세요" : "음정을 조금 낮추세요")
    }
}

private struct TuningPitchGraph: View {
    let noteName: String?
    let cents: Double?
    let feedback: String
    let isInTune: Bool

    var body: some View {
        GeometryReader { geometry in
            let center = geometry.size.width / 2
            let normalized = CGFloat(max(-50, min(50, cents ?? 0)) / 50)
            let axisY = geometry.size.height * 0.34
            let markerX = isInTune ? center : center + normalized * (center - 42)
            ZStack {
                Canvas { context, size in
                    var ticks = Path()
                    ticks.move(to: CGPoint(x: 42, y: axisY))
                    ticks.addLine(to: CGPoint(x: size.width - 42, y: axisY))
                    for index in 0...20 {
                        let x = 42 + (size.width - 84) * CGFloat(index) / 20
                        let length: CGFloat = index.isMultiple(of: 5) ? 10 : 5
                        ticks.move(to: CGPoint(x: x, y: axisY - length))
                        ticks.addLine(to: CGPoint(x: x, y: axisY + length))
                    }
                    context.stroke(ticks, with: .color(Color.primary.opacity(0.13)), lineWidth: 1)
                    var reference = Path()
                    reference.move(to: CGPoint(x: center, y: 4))
                    reference.addLine(to: CGPoint(x: center, y: size.height - 4))
                    context.stroke(reference, with: .color(isInTune ? Color.instrumentAccent.opacity(0.65) : Color.primary.opacity(0.16)), lineWidth: 1.5)
                }
                HStack { Text("♭"); Spacer(); Text("♯") }
                    .font(.title2).foregroundStyle(.secondary)
                    .position(x: center, y: axisY)
                Circle()
                    .fill(Color.tunerSurface)
                    .overlay(Circle().stroke(isInTune ? Color.instrumentAccent : Color.secondary, lineWidth: 2.5))
                    .overlay {
                        if isInTune {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.instrumentAccent)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .position(x: markerX, y: axisY)
                    .animation(.snappy(duration: 0.16), value: cents)
                Group {
                    if let noteName {
                        Text(noteName)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundStyle(isInTune ? Color.instrumentAccent : Color.primary)
                            .frame(width: 56, height: 50)
                    } else {
                        Text("줄을 튕겨 주세요").font(.footnote).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).frame(height: 40)
                    }
                }
                .background(Color.tunerSurface)
                .position(x: center, y: geometry.size.height * 0.76)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noteName ?? "감지된 음 없음"). \(feedback)")
        }
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct HeadstockStringPicker: View {
    let tuning: GuitarTuning
    let selectedString: GuitarString?
    let lockedString: GuitarString?
    let onSelect: (GuitarString) -> Void

    var body: some View {
        GeometryReader { geometry in
            let headHeight = min(geometry.size.height, max(0, geometry.size.width - 112) / 0.72)
            let headWidth = headHeight * 0.72
            let inset = (geometry.size.height - headHeight) / 2
            let diameter: CGFloat = headHeight < 270 ? 44 : 52
            ZStack {
                GuitarHeadstock(selectedString: selectedString)
                    .frame(width: headWidth, height: headHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .accessibilityHidden(true)
                ForEach(HeadstockStringRoute.all, id: \.string) { route in
                    let target = TunerPitchReading(midi: Double(tuning.midi(for: route.string)))
                    let selected = route.string == selectedString
                    Button { onSelect(route.string) } label: {
                        Text(target.pitchClassName).font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(selected ? Color.instrumentAccent : Color.primary)
                        .frame(width: diameter, height: diameter)
                        .background(selected ? Color.instrumentAccent.opacity(0.09) : Color(uiColor: .secondarySystemBackground), in: Circle())
                        .overlay(Circle().stroke(selected ? Color.instrumentAccent : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .position(x: route.post.x < 0.5 ? diameter / 2 : geometry.size.width - diameter / 2,
                              y: inset + route.post.y * headHeight)
                    .accessibilityLabel("\(route.string.number)번 현, \(target.noteName)")
                    .accessibilityHint(lockedString == route.string ? "다시 누르면 자동 감지로 돌아갑니다." : "이 현의 음정을 맞춥니다.")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

private struct GuitarHeadstock: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedString: GuitarString?

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                // Shafts and keys sit behind the wood, one pair for each post.
                ForEach(HeadstockStringRoute.all, id: \.string) { route in
                    let left = route.post.x < 0.5
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(white: 0.45), .white, Color(white: 0.48)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.235, height: max(3, h * 0.012))
                        .position(x: w * (left ? 0.1725 : 0.8275), y: h * route.post.y)
                    RoundedRectangle(cornerRadius: w * 0.025)
                        .fill(LinearGradient(colors: [Color(white: 0.93), Color(white: 0.65), Color(white: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: w * 0.025).stroke(Color(white: 0.4), lineWidth: 0.7))
                        .frame(width: w * 0.11, height: h * 0.085)
                        .position(x: w * (left ? 0.06 : 0.94), y: h * route.post.y)
                }
                HeadstockShape()
                    .fill(LinearGradient(colors: colorScheme == .dark ? [Color(red: 0.28, green: 0.18, blue: 0.12), Color(red: 0.19, green: 0.12, blue: 0.085)] : [Color(red: 0.83, green: 0.80, blue: 0.74), Color(red: 0.75, green: 0.71, blue: 0.64)], startPoint: .leading, endPoint: .trailing))
                    .overlay(HeadstockShape().stroke(colorScheme == .dark ? Color(red: 0.65, green: 0.48, blue: 0.32) : Color(red: 0.59, green: 0.55, blue: 0.48), lineWidth: 1.2))
                Rectangle()
                    .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.105, blue: 0.09) : Color(red: 0.43, green: 0.40, blue: 0.35))
                    .frame(width: w * 0.34, height: h * 0.16)
                    .position(x: w / 2, y: h * 0.92)
                Canvas { context, _ in
                    for y: CGFloat in [0.915, 0.985] {
                        var fret = Path()
                        fret.move(to: CGPoint(x: w * 0.33, y: h * y))
                        fret.addLine(to: CGPoint(x: w * 0.67, y: h * y))
                        context.stroke(fret, with: .color(Color(white: 0.55)), lineWidth: 1.3)
                    }
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.91, green: 0.87, blue: 0.75))
                    .frame(width: w * 0.36, height: max(4, h * 0.016))
                    .position(x: w / 2, y: h * HeadstockStringRoute.nutY)
                Canvas { context, _ in
                    for route in HeadstockStringRoute.all {
                        let selected = route.string == selectedString
                        let style = StrokeStyle(lineWidth: selected ? 2.4 : route.width, lineCap: .round, lineJoin: .round)
                        let nut = CGPoint(x: route.nut.x * w, y: route.nut.y * h)
                        var neckString = Path()
                        neckString.move(to: CGPoint(x: route.nut.x * w, y: h))
                        neckString.addLine(to: nut)
                        context.stroke(neckString, with: .color(selected ? .mint : Color(red: 0.79, green: 0.77, blue: 0.66)), style: style)
                        var headString = Path()
                        headString.move(to: nut)
                        headString.addLine(to: CGPoint(x: route.post.x * w, y: route.post.y * h))
                        let ink = colorScheme == .dark ? Color(red: 0.79, green: 0.77, blue: 0.66) : Color(red: 0.34, green: 0.29, blue: 0.23)
                        context.stroke(headString, with: .color(selected ? (colorScheme == .dark ? .mint : .instrumentAccent) : ink), style: style)
                    }
                }
                ForEach(HeadstockStringRoute.all, id: \.string) { route in
                    ZStack {
                        Circle().fill(Color(white: 0.7))
                        Circle().stroke(Color(white: 0.35), lineWidth: 1)
                        Circle().fill(Color(white: 0.94)).padding(w * 0.016)
                        Circle().fill(Color(white: 0.38)).padding(w * 0.03)
                    }
                    .frame(width: w * 0.086, height: w * 0.086)
                    .position(x: route.post.x * w, y: route.post.y * h)
                }
                Text("muttan")
                    .font(.system(size: max(9, w * 0.048), weight: .medium, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? Color(red: 0.85, green: 0.75, blue: 0.54) : Color(red: 0.34, green: 0.31, blue: 0.26))
                    .position(x: w / 2, y: h * 0.115)
            }
        }
    }
}

private struct HeadstockShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * rect.width, y: y * rect.height) }
        var path = Path()
        path.move(to: point(0.23, 0.04))
        path.addQuadCurve(to: point(0.5, 0.025), control: point(0.34, 0.025))
        path.addQuadCurve(to: point(0.77, 0.04), control: point(0.66, 0.025))
        path.addQuadCurve(to: point(0.83, 0.105), control: point(0.83, 0.04))
        path.addLine(to: point(0.78, 0.70))
        path.addCurve(to: point(0.67, 0.84), control1: point(0.77, 0.77), control2: point(0.68, 0.78))
        path.addLine(to: point(0.67, 1))
        path.addLine(to: point(0.33, 1))
        path.addLine(to: point(0.33, 0.84))
        path.addCurve(to: point(0.22, 0.70), control1: point(0.32, 0.78), control2: point(0.23, 0.77))
        path.addLine(to: point(0.17, 0.105))
        path.addQuadCurve(to: point(0.23, 0.04), control: point(0.17, 0.04))
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
    @Published private(set) var permissionDenied = false

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
        permissionDenied = false
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
                    self.permissionDenied = true
                    self.statusMessage = "설정에서 마이크 접근을 허용해 주세요."
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
                statusMessage = "마이크를 사용할 수 없어요."
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
            statusMessage = "마이크를 시작할 수 없어요. 다시 시도해 주세요."
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
