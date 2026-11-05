# 오디오 입력과 실시간 처리

## 현재 앱 기준선

- [`TunerView.swift`](../../../muttan/Features/Practice/TunerView.swift)가 `AVAudioEngine` 입력 노드에 tap을 설치하고, 4096프레임 버퍼를 요청한다.
- 공용 `Play` 화면은 [`PracticeFeature.swift`](../../../muttan/Features/Practice/PracticeFeature.swift)에서 1024프레임 tap을 요청하고, 2048샘플 rolling window에서 YIN 추정 및 에너지/피치 변화 온셋 후보를 계산한다. 1024프레임은 44.1 kHz에서 약 23ms지만 실제 callback 크기·간격과 처리 지연은 실기기에서 확인하지 않았다.
- 입력은 `.playAndRecord`와 `.measurement` 오디오 세션으로 구성된다.
- 현재 세션은 `.allowBluetoothHFP`를 허용한다. Apple 문서에 따르면 HFP 입력/출력을 선택하면 양방향 라우트가 함께 전환되므로, 튜너/연습은 실제 route와 hardware format을 읽고 비교해야 한다.
- 분석을 직렬 큐로 넘기며 오래된 분석 결과, 권한 상태, 화면 이탈 시 종료를 관리한다.
- 화면이 백그라운드로 가면 중지하고 복귀 시 재시작한다. interruption 시작과 입력 장치 분리에는 안내 후 일시정지한다. interruption 종료·라우트 재구성 후 자동 재개 여부는 현재 흐름에서 처리하지 않는다.
- `TunerView`는 세션 route-change에서 `.oldDeviceUnavailable`만 pause 처리한다. `.newDeviceAvailable`/`routeConfigurationChange` 및 engine configuration notification을 받아 입력 포맷이 달라진 뒤 tap을 재설치하는 경로는 현재 확인되지 않는다.
- `PitchDetector`는 전달받은 샘플의 실제 `sampleRate`로 주파수를 계산한다.
- tap 콜백의 `AVAudioTime` 인자는 현재 무시한다. `capturedAt`은 콜백 진입 직후 uptime으로 기록되므로 샘플의 정확한 캡처 시각 대신 콜백 도착 근사치로 보아야 한다.
- 튜너 tap 요청은 4096프레임이며 로그의 `bufferFrames`는 요청값을 기록한다. 실제 `buffer.frameLength`는 오디오 처리 중 읽으며, 요청값과 구별해 기록해야 한다. Play tap의 요청은 1024프레임이다.
- tap callback은 채널 `UnsafeBufferPointer`를 `[Float]`에 복사한 뒤 직렬 큐로 보낸다. 결과 분석은 끝나도 `permit`은 main actor의 UI update가 실행될 때까지 점유한다. 다음 callback은 permit이 없으면 즉시 폐기하며 현재 drop 수는 기록하지 않는다.

이 구성은 마이크 기반 튜너와 단음 연습의 MVP 출발점이다. 튜너와 연습의 요청 크기는 다르며, 어느 쪽도 요청 버퍼 크기가 실제 프레임 수나 응답 시간을 보장하지 않는다.

## 근거로 확인한 사실

1. Apple의 [`AVAudioEngine.inputNode`](https://developer.apple.com/documentation/AVFAudio/AVAudioEngine/inputNode) 문서는 입력 노드의 하드웨어 포맷에서 유효한 샘플레이트와 채널 수를 확인하도록 한다. 입력 사용 불가/비활성 상태면 오류가 발생할 수 있다.
2. Apple의 [`installTap`](https://developer.apple.com/documentation/avfaudio/avaudionode/installtap%28onbus%3Abuffersize%3Aformat%3Ablock%3A%29) 문서는 tap의 버퍼 크기가 구현에 의해 달라질 수 있고 콜백이 메인 스레드가 아닐 수 있다고 명시한다.
3. [`AVAudioSession` I/O buffer duration API](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferrediobufferduration%28_%3A%29)는 선호값을 요청하는 API다. 런타임에서 실제 `ioBufferDuration`, 샘플레이트, 라우트를 확인해야 한다.
4. 오디오 하드웨어 구성이 바뀌면 엔진이 정지·재초기화될 수 있으므로 [`AVAudioEngineConfigurationChangeNotification`](https://developer.apple.com/documentation/AVFAudio/AVAudioEngineConfigurationChangeNotification)을 관찰하고 재시작 경로를 다뤄야 한다. 현재 TunerView 코드에서 이 notification 관찰은 발견하지 못했다.
5. Apple은 [오디오 interruption](https://developer.apple.com/documentation/AVFAudio/handling-audio-interruptions) 및 [route change](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes?changes=_9) notification에 맞춰 상태를 갱신하도록 안내한다. 입력을 듣는 연습에서 헤드폰/입력 장치 분리 뒤 자동으로 마이크를 다시 여는 것보다, 끊긴 이유를 보여주고 사용자가 재시작하는 편이 예측 가능하다.
6. [`measurement` 모드](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/measurement)는 시스템이 제공하는 signal processing을 최소화하려는 용도이며, 일부 dynamics processing을 비활성화한다. 현재 튜너 설정과 맞는 선택이지만, 자동으로 최적 마이크나 최고 음정 검출을 보장하지 않는다. 여러 내장 마이크 기기에서는 primary microphone을 사용한다고 명시되어 있다.
7. [`allowBluetoothHFP`](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetooth?changes=_9)는 HFP 기기가 입력 라우트로 나타나도록 허용한다. HFP input을 고르면 출력도 대응 HFP output으로 전환될 수 있다. 이는 곡 재생/반주와 마이크 입력의 라우팅 선택에 직접 영향이 있으므로 실제 경로에서 별도 확인한다.
8. Apple의 [audio performance with Instruments](https://developer.apple.com/documentation/audiotoolbox/analyzing-audio-performance-with-instruments) 안내는 lock 대기·메모리 할당·과한 연산이 audio-server 시간 예산을 넘기면 glitch를 유발할 수 있다고 설명하고 Audio System Trace로 I/O callback과 overload를 추적하는 방법을 제시한다. 현재 tap callback의 `[Float]` 복사는 allocation이므로 실기기 프로파일에서 그 비용을 확인한다.

## 권장 처리 경계

```text
마이크 → AVAudioEngine input tap → 빠른 샘플 수집/시각 부여
      → 직렬 분석 큐 → 유효성·온셋·F0 분석
      → 세션 토큰/시각 검증 → 메인 큐 UI 상태 갱신
```

- Tap에서 할 일은 작게 유지한다. 할당·로그 폭증·대기·UI 갱신은 실시간 콜백에 넣지 않는다.
- 현재 callback에서 동적 배열 복사가 일어난다. 실기기에서 callback 실행 시간, allocation pressure, permit drop이 온셋/반복음 누락과 상관 있는지 먼저 측정한다. “한 버퍼만 유지”는 큐 폭증을 막지만 낮은 지연과 이벤트 무손실을 함께 보장하지 않는다.
- 오디오 프레임 시각은 callback 도착 시각이 아닌 `AVAudioTime`과 프레임 정보를 사용해 추적한다. 현재 코드는 callback의 `AVAudioTime`을 사용하지 않으므로, 리듬 판정 전 이를 반영하고 시계 도메인 변환을 검증한다.
- 분석 작업이 밀리면 이전 프레임을 무한히 쌓기보다 오래된 결과를 버린다. 단, 온셋 검출용 시간 연속성을 해치지 않도록 drop 횟수를 계측한다.
- 앱이 요청한 버퍼와 런타임에서 관찰한 버퍼를 구분해 로그/성능 표에 기록한다.
- 블루투스·헤드폰·내장 스피커 등 라우트 변경, 전화 인터럽션, 백그라운드 진입과 복귀를 별도 상태 전이로 처리한다.

## 아직 측정할 항목

기기와 라우트별로 최소한 다음을 기록한다: 하드웨어 샘플레이트/채널, tap `frameLength`, tap 콜백 간격, 실제 I/O buffer duration, callback 시간, permit drop count, 프레임 캡처부터 결과 산출까지 시간, 분석 큐 대기, UI 반영까지의 p50/p95, interruption 및 configuration change 후 복구 성공 여부. 지금 로그에는 포맷과 요청 버퍼가 있으나, 실제 frameLength/drops와 전체 latency breakdown은 아직 구현되어 있지 않다. CPU/audio overload가 의심되면 Instruments Audio System Trace로 callback deadline 초과 여부를 확인한다.

4096 프레임은 44.1 kHz에서 약 93 ms 분량이지만, tap 콜백의 요청값이 그대로 적용된다고 가정할 수 없고 UI 지연 전체도 이것 하나로 계산할 수 없다. 버퍼를 줄이는 것은 측정 후 결정한다.

계산상 입력 창은 `frameCount / actualSampleRate`다. 예를 들어 44.1 kHz에서 2048프레임은 약 46ms, 4096프레임은 약 93ms다. `비행기`의 가장 낮은 목표 C4는 약 262Hz이므로 2048 샘플 안에 약 12주기가 들어간다. 이것은 음정 안정성의 증거가 아니며 비교를 시작할 만한 candidate window일 뿐이다. 실험 후보로 2048 샘플 분석창 + 512 샘플 hop을 4096 샘플 창과 비교할 수 있다. 이때 새 판정 빈도는 약 11.6ms(44.1kHz)일 수 있지만, 음이 시작된 뒤 충분한 분석 창을 채우는 시간과 정확도/CPU 비용은 따로 측정한다.

기준값·실험값을 한 필드에 섞지 않는다.

| 시간 구간 | 현재 코드 | 조사 후보 |
| --- | --- | --- |
| tap 요청 | 튜너 4096, Play 1024 frames | 요청 크기별 실제 `frameLength` 확인 |
| F0 입력 window | 튜너 전체 callback buffer, Play 2048-sample rolling window | 2048/4096 samples와 개별 장단점 비교 |
| hop/cadence | Play는 1024-sample input hop, pitch는 보통 2048 input samples마다 분석 | rolling window 512-sample hop 검토 |
| callback/drop | serial 분석 + main actor 반영까지 permit 점유, 바쁘면 buffer drop | callback 실행시간, permit wait/drop, 분석 종료와 UI 반영을 구분해 기록 |
| latency | callback 진입 uptime 기준으로 reading age | AVAudioTime capture → 분석 → UI 반영 단계별 측정 |

## 후속 결정

1. `TunerView`의 현재 입력 세션 흐름과 로그 필드를 파악한다. 확인된 route/engine configuration gap의 빈도·영향을 실기기에서 조사한다.
2. 실기기 한 대에서 기본 라우트 기준을 측정하고 결과를 남긴다.
3. 0–1–2–3 훈련과 `비행기`에서 단음·반복 타격 반응 문제가 확인될 경우에만 선호 I/O buffer 요청을 시도한다.
4. 변경 전후에 누락, CPU/발열, 입력 지연, 세션 복구를 함께 비교한다.

## 참고

- Apple, [AVAudioEngine input node](https://developer.apple.com/documentation/AVFAudio/AVAudioEngine/inputNode)
- Apple, [AVAudioNode install tap](https://developer.apple.com/documentation/avfaudio/avaudionode/installtap%28onbus%3Abuffersize%3Aformat%3Ablock%3A%29)
- Apple, [Set preferred I/O buffer duration](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferrediobufferduration%28_%3A%29)
- Apple, [AVAudioEngine configuration change notification](https://developer.apple.com/documentation/AVFAudio/AVAudioEngineConfigurationChangeNotification)
- Apple, [AVAudioTime](https://developer.apple.com/documentation/avfaudio/avaudiotime): 한 시각을 host time, sample time 또는 두 형식으로 표현하며 validity flag를 확인할 수 있다.
