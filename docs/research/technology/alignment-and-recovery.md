# 연주 타임라인과 오류 복구

## 문제 정의

연습 화면은 다음 목표 음, 실제 입력, 오디오 분석 결과, 재시작 위치를 하나의 진행 상태로 관리해야 한다. 오디오 분석 결과는 입력보다 늦게 도착할 수 있으므로, UI가 도착 순서만 보고 정답을 판단하면 과거 이벤트를 현재 이벤트에 적용할 수 있다.

## 작은 상태 모델

```text
ready → listening → accepted → advancing
                  ↘ mismatch → retry cue → replay segment
                  ↘ no input → wait / retry prompt
```

- `mismatch`는 신뢰도 있는 음이 목표와 다를 때만 만든다.
- `no input`은 오답과 분리하고 사용자에게 자연스럽게 계속할 선택지를 남긴다.
- 각 입력·전환에 세션 ID와 이벤트 인덱스를 붙여 화면을 나간 뒤 도착한 늦은 결과를 무시한다.
- beat clock은 연습이 대기 중일 때 일시 정지할지 진행할지 상태로 명시한다. 제품 계획은 소리가 없는 동안 진행을 자동으로 앞당기지 않고 `계속` 버튼을 제공하므로, 다음 이벤트에서 박자 기준 시점을 다시 잡아야 한다.
- 오류 처리 상태에서 추가 프레임이 여러 번 오더라도 되감기는 한 번만 예약한다.
- 재시작은 대상 구간의 시작 시각/이벤트 인덱스 기준으로 실행하고, 버튼/자동 재시작 중복으로 두 번 실행되지 않게 한다.

## 초기 경험 권고

현재 [연습 시제품 계획](../../plans/song-practice.md)은 안정적인 오답 뒤 약 300ms 쉬고 1.5초 앞 이벤트 시각으로 되감은 다음, 300ms 숨 고르기와 2박 카운트인으로 자동 재개하도록 정했다. 기술적으로는 곡 전체 오디오를 seek하지 않고 이벤트 playhead를 계산된 이벤트 인덱스로 되돌리면 된다. 패턴 첫 1.5초는 이벤트 0으로 clamp한다. UX가 자연스러운지는 실기기 시제품에서 검증하되, 첫 구현은 제품 명세를 기준으로 한다.

**박자 기준점은 구현 전에 명확히 해야 한다.** BPM 72에서 한 박은 약 833ms이며 2박은 약 1,667ms다. 고정 1.5초 이동은 약 1.8박이므로, 두 박 카운트인을 그 이동 뒤에 단순히 이어 붙이면 다음 목표 시각이 원래 격자에서 약 167ms 밀릴 수 있다. 오답이 난 이벤트의 기준 박자 또는 재시작할 다음 이벤트를 anchor로 고정하고 두 박 카운트인은 그 앞에 두는 편이 오차 누적을 막는다. “1.5초 전”이 정확한 타임라인 이동량인지, 대상 음 주변으로 돌아갈 UX 길이인지 구현 계획에서 확인한다.

제품 계획의 입력 허용창 ±35% beat는 BPM 72에서 약 ±292ms다. 이것은 명세의 초기 선택값이며 음악적으로 맞는 보편적 허용 범위가 아니다. 실험에서는 onset 지연의 절댓값만 보지 말고 빠른 입력과 늦은 입력을 따로 분리해 허용창의 false accept / false reject를 본다.

같은 음이 연속되는 마디에서는 오답 판정만으로 두 번의 타격을 구별할 수 없다. 정확한 다음 이벤트에서 새 onset을 요구하고, onset이 없는 동안 재생 시계가 자동으로 앞서가지 않도록 계획한다. 소리가 없을 때는 판정을 멈추고 `계속` 조작을 제공한다.

두 박 카운트인, 기준 음, 메트로놈 소리를 앱에서 낼 때 `AVAudioPlayerNode`/`AVAudioSequencer`의 scheduled start, 샘플 타임과 화면 타임라인 동기화, 오디오 출력 지연을 추가 조사한다. 기준 음만 여러 번 재생하는 초기 구현은 작은 PCM buffer/파일과 `AVAudioPlayerNode`로 충분한지 먼저 비교한다. 곡 반주 전체와 마이크 동시 입출력은 현재 요구에 없다.

## 카운트인·기준음 출력

- Apple의 [`AVAudioPlayerNode`](https://developer.apple.com/documentation/avfaudio/avaudioplayernode)는 PCM buffer나 파일 segment를 특정 `AVAudioTime`에 예약할 수 있다. `stop()`은 예약 이벤트를 지우고 player time을 0으로 되돌린다.
- 오디오 시계는 앱 `Timer` 주기로 클릭 소리를 직접 만들지 않는다. sample time을 기준으로 두 박을 예약하고, 악보·playhead는 같은 세션의 단조 타임라인에서 표시한다. UI animation은 이 타임라인을 따라가며 정답 판정은 렌더링 시각이 아니라 목표 beat 및 캡처된 입력 시각으로 한다.
- 박자 시각은 이전 tick에 833ms를 계속 더하지 않고 세션 anchor + 정수 beat index에서 계산한다. 12마디 × 4/4 × 72 BPM은 count-in을 제외하면 48박, 약 40초다. 반복 `Timer` 누적 오차가 마디 진행 오차로 번지는 일을 막고 seek/resume 뒤에도 목표 이벤트의 beat index를 고정할 수 있다.
- `AVAudioTime`을 output schedule에 넘길 때 host/sample time validity와 engine sample rate가 맞는지 확인한다. input tap의 time과 output player timeline은 서로 다른 clock representation일 수 있으므로 변환·기준 anchor를 확인한다.
- reference note를 사용할 때는 playback 상태가 마이크 신호의 주파수 검출에 영향을 주는지 검사한다. 초기 계획은 입력 중 안내음을 작게 재생하고 사용자의 입력을 듣는다. 마이크가 기준음 자체를 잡아 정답으로 오인하지 않도록, 음 재생 직후 입력 gate, 출력 volume, 헤드폰 route, harmonic/noise 조건을 비교한다.
- 현재 튜너는 `.measurement` mode를 쓴다. 이 모드는 시스템 dynamics processing을 줄이며 Apple은 playback level이 낮아질 수 있다고 설명한다. 연습 출력도 같은 세션을 공유하면 기준음 volume/톤을 실제 route별로 확인한다.
- 고정 BPM 72의 첫 곡은 템포 추정 엔진이나 복잡한 sequencer 기능을 요구하지 않는다. 8분음표·쉼표·반복 등 이벤트가 늘어날 때 직접 이벤트 배열과 `AVAudioSequencer`를 비교한다.

## 출력 비교 기준

내장 스피커·유선/USB·HFP route에서 count-in 기준 박과 화면 표시의 오차, reference note 종료 후 input false-positive 시간, output/input buffer duration, interruption 후 출력 재예약, pause/seek/tempo change 상태 일관성을 측정한다. 사용자 기본값은 소리 끔으로 유지하고 필요 시 기준음/카운트인만 켤 수 있도록 한다.

## 검증 항목

- 오래된 결과가 다음 타깃 음 상태를 바꾸지 않는가?
- count-in·reference audio의 sample-time과 악보 playhead가 일정하게 정렬되는가?
- 안내음 재생이 사용자의 같은 음 입력으로 오인되지 않는가?
- 여러 분석 결과가 연속 오답을 보내도 재시작은 한 번인가?
- 일시적 낮은 confidence를 오답으로 처리하지 않는가?
- 사용자가 입력하지 않았을 때 자동 재시작 루프에 갇히지 않는가?
- 화면 전환·인터럽션 후 이전 세션의 이벤트가 살아나지 않는가?
- 사용자에게 “다시 시작되는 이유와 위치”가 시각적으로 명확한가?

실시간 오디오 캡처와 UI 상태 연결은 [오디오 입력](audio-capture.md), 음과 타격 판단은 [단음 음정 추정](pitch-detection.md), [온셋·리듬](onset-and-rhythm.md)을 참조한다.
