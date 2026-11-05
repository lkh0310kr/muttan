# 평가 자료와 비교 절차

## 비교 목적

이 평가는 신경망을 학습하거나 앱에 오디오를 저장하는 작업이 아니다. 현재 Swift YIN과 에너지/피치 변화 onset 기준선이 0–1–2–3 훈련과 `비행기`에서 요구하는 음·타격·타이밍 피드백을 제공할 수 있는지 확인하고, 실패가 재현될 때만 후보 방법을 비교한다.

## 자료 계층

| 자료 | 적합한 질문 | 주의할 점 |
| --- | --- | --- |
| GuitarSet의 acoustic mono mic 채널과 주석 | F0/onset/chord 알고리즘의 오프라인 참조 기준 | 실제 iPhone 음향·방 거리·사용자 거리/각도를 대표하지 않음; Zenodo 기록의 파일 조건과 오류 목록 확인 |
| GuitarSet hex-pickup 채널 | 현별 음·프렛 라벨을 확인하는 분석 참조 | 픽업 입력은 스마트폰 공기 마이크와 음색/잡음 특성이 다름 |
| Fraunhofer IDMT-SMT-GUITAR | dry electric 기타, 다양한 표현/코드·리듬 자료에서 후보 비교 | 주된 자료가 기타 출력 직접 연결; 공개 기준 CC BY-NC-ND라 재배포·변형 조건을 주의 |
| 앱용 직접 iPhone 입력 | 실제 UI 지연과 사용자 체감, 환경 잡음에서의 결정 | 연구 평가용 음원은 세션과 구분해 로컬 임시 기록, 접근 통제 및 종료 후 삭제. 앱의 기본 동작은 계속 저장하지 않음 |

GuitarSet은 어쿠스틱 기타의 음고 윤곽, 현/프렛, 코드, 박/강박, 연주 스타일 주석과 여러 수음 방식이 있다는 점에서 기타 연구에 유용하다. 다만 실제 연습 중 iPhone의 단일 마이크에 들어오는 소리와 일치한다고 볼 수 없다. 공개 자료 결과와 휴대폰 입력 결과를 한 점수로 섞지 말고 따로 보고한다.

## 시험 케이스

각 케이스는 정답 이벤트를 미리 기록하고 같은 구절을 반복한다. 최소한 기본 조건과 약한 타격, 잔향/연타, 버징, 가정 소음, 의도한 오답 음, 무음, 출력 기준음 영향, 앱 interruption 복귀를 분리한다.

| 케이스 | 확인 사항 |
| --- | --- |
| 훈련·곡의 일반 단음 | 훈련의 E4–G4 및 곡의 C4–A4 F0 판정, onset 위치, 화면 반응 |
| 같은 pitch 반복 | 두 이벤트를 서로 다른 onset으로 감지하는가 |
| 틀린 안정 음 | 목표와 다른 pitch를 오답으로 판정하고 한 번만 복구하는가 |
| 낮은 레벨/잡음 | no-input과 wrong-note가 구분되는가 |
| 이어지는 잔향/짧은 쉼 | 두 번째 발음 누락 또는 한 번의 타격 중복 검출 여부 |
| 재시작/click/reference note | 악보 박과 출력 시각이 정렬되고 재생음이 자기 입력으로 오인되지 않는가 |
| route/interruption | 오래된 세션 결과 폐기, 재시작 안내, 탭 제거/엔진 재생성 |

## 지표

- **Pitch:** 음을 판정한 voiced 프레임의 ±50 cent 정확도, 다른 음의 오수용률, 타깃이 울렸는데 무응답인 비율, octave error, median 및 p95 cent error. DAFx 기타 추적 연구의 ±50 cent 허용은 비교 가능한 기준이지만, 제품 UX를 위한 교육적 진실값은 아니다.
- **Onset:** 정답 타격 하나에 검출 하나를 일대일 매칭한 precision/recall/F1, 중복·누락 수, onset 지연 median/p95. 허용 시간 창을 보고서에 명시하고 제품 계획의 BPM 기반 ±35% 창과 연구 알고리즘의 평가 창을 혼동하지 않는다.
- **End-to-end:** 입력 audio frame부터 결과 state/UI 반영까지 median/p95, 입력을 기다린 시간, 오답 후 실제 재시작 목표와의 박자 오차.
- **Runtime:** 분석 drop 수, queue wait, CPU/발열, session/route interruption recovery. 마이크 라우트별 실제 sample rate·channel·buffer size를 기록한다.

분모를 구분한다: 모든 목표 이벤트 중 정답, 틀린 입력 중 실제 오답 감지, 무음 중 잘못 발동한 수, 분석이 아예 불가능했던 타깃 수. 하나의 전체 accuracy만 보고하면 무응답/오답 수용 문제를 숨길 수 있다.

## 실험 기록 형식

음성 파일 없이도 비교 결과를 재현할 수 있도록 실행 조건과 이벤트 결과를 표로 기록한다. 음성 원본은 필요한 단독 시험에만 별도 임시 보관한다.

실행(run) 단위에는 기기 모델, iOS 버전, 입력 라우트, 실제 샘플레이트·채널, 요청 tap 프레임, 관찰한 `frameLength`, F0 알고리즘 버전, BPM과 세션 옵션을 기록한다. 이벤트 단위에는 이벤트 인덱스, 기대 MIDI와 목표 박, 추정 MIDI·clarity, onset 유무와 시각, 최종 분류, 캡처부터 UI까지 시간, dropped buffer 수를 기록한다.

정답 라벨은 target-event manifest에서 가져오고 실제 추정값은 device run에서 기록한다. 측정 전 미지 값은 `unknown`으로 둔다. 안정적인 identity/serial number나 waveform bytes는 로그에 넣지 않는다.

## 비교 순서

1. 현재 YIN과 에너지 상승 onset baseline을 같은 iPhone 입력과 같은 정답 annotation으로 측정한다.
2. 오류를 유형별로 분류한다. 예: 낮은 레벨 미검출, 옥타브 오류, 같은 음 재타격 누락, 기준음 자체 오인, 높은 UI 지연.
3. pitch가 문제라면 동일 샘플에서 MPM 또는 aubio YINFFT/pYIN 후보 하나를 추가한다. onset이 문제라면 spectral flux 하나를 추가한다.
4. 대조 방법은 해당 문제 지표를 개선하는지, 다른 지표(지연, false positive, CPU)를 악화하는지 비교한다.
5. 개선이 기기 입력에서 재현될 때만 구현 선택을 바꾼다. 공개 dataset score alone으로 채택하지 않는다.

## 공개 자료 사용과 보관

- 공개 데이터는 알고리즘 비교용 별도 평가도구로만 쓴다. 원본 오디오/annotation은 제품 번들에 넣지 않는다.
- [GuitarSet Zenodo record](https://zenodo.org/records/3371780)에서 개별 파일, 출처 표기, 기록에 표시된 알려진 annotation error를 확인한다. 이용/재배포 조건이 명확하지 않으면 변경·배포하지 않는다.
- [Fraunhofer IDMT-SMT-GUITAR](https://www.idmt.fraunhofer.de/en/publications/datasets/guitar.html)는 평가 목적의 이용 및 CC BY-NC-ND 조건을 안내한다. 재배포하지 않고 원 출처 조건을 확인한다.
- 사용자가 연습 중 내는 소리는 제품에서 저장·전송하지 않는다. 연구를 위해 별도 캡처한 임시 파일은 테스트 동의·저장 위치·삭제시점을 명시하고, 일반 앱 로그에는 파형이나 음성 샘플을 기록하지 않는다.
