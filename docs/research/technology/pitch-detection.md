# 단음 음정 추정

## 범위와 현재 구현

첫 연습은 C장조 단음 멜로디 `비행기`의 타깃 음·박자·현·프렛을 미리 정의해 두고 사용자가 따라 치는 과제다. 이 범위의 오디오 분석은 **단음 기본 주파수(F0)** 추정 문제다. 화음 인식이나 여러 현을 동시에 치는 코드 분류와는 다른 문제다.

현재 [`PitchDetector.swift`](../../../muttan/Features/Practice/PitchDetector.swift) 구현은 다음과 같다.

- 평균값을 제거한 샘플의 RMS가 0.008보다 클 때만 처리한다.
- 기본 탐색 범위는 60–1000 Hz이고 입력 버퍼는 최소 2048 샘플이어야 한다.
- YIN의 cumulative mean normalized difference (CMNDF)로 주기 후보를 고른다.
- threshold 0.14 및 clarity `1 - CMNDF` 0.75 기준을 사용하고, 포물선 보간으로 주파수를 다듬는다.
- 이는 한 프레임의 추정기다. 같은 음을 다시 튕겼는지, 타이밍이 맞았는지는 판정하지 않는다.
- `clarity`는 이 구현에서 계산한 주기성 점수이지 확률 보정된 “정답일 가능성”이 아니다. 0.75가 실제 입력에서 75% 정확도를 뜻하지 않는다.

[`TunerSignal.swift`](../../../muttan/Features/Practice/TunerSignal.swift)에서도 clarity와 입력 신선도를 확인한다. 현재 상수는 구현 기준값이지 iPhone 기타 입력에서 검증된 최적값은 아니다.

세부적으로 CMNDF 임계값 아래의 일반 candidate 선택은 trough가 0.14 아래가 될 때까지 탐색하므로 반환 clarity는 보통 0.86 이상이다. 0.75–0.86 구간은 threshold crossing이 없는 fallback 경로에서만 통과할 수 있다. `TunerSignal`에도 0.75 검사가 한 번 더 있다. 이 이중 조건을 간소화할지 결정하기 전에 실기기 샘플의 정답 수용/오답 수용을 측정하고, 계산된 clarity와 제품에서 말하는 confidence를 구별한다.

## 후보 방법 비교

| 접근 | 강점 | 주의점 | 이 앱에서의 역할 |
| --- | --- | --- | --- |
| YIN / CMNDF | 단음 음성·음악의 주기 추정에 잘 알려진 기준선; 현재 구현 보유 | 공격 구간과 배음 강조 음에서 옥타브 오류/미검출 여부를 실제 기타로 확인해야 함 | 우선 유지하고 동일 샘플 기준선 측정 |
| YINFFT / YINFAST | aubio 구현에서 스펙트럼 계산 또는 가속 등 변형을 비교할 수 있음 | 다른 구현의 성능을 곧바로 현재 Swift 코드 성능으로 일반화할 수 없음 | 결과가 늦거나 누락될 때 비교 |
| MPM (McLeod Pitch Method) | 정규화 squared-difference 방식이며 tonal clarity 값을 제공 | YIN과 계열이 가깝고 MPM clarity 숫자는 YIN CMNDF clarity와 보정/단위가 같다고 보장되지 않음 | F0·유효/무효 판정 성능을 낮은 주파수/공격 구간에서 대조 |
| 스펙트럼 피크/조화 comb | 배음 구조를 명시적으로 이용할 수 있음 | 단일 최대 피크가 기본음이 아닐 수 있고, 저음 해상도·프레임 길이 영향 | 하모닉 오인 유형이 재현되면 대조군 |
| pYIN | YIN 후보를 확률적으로 다루고 시간 문맥으로 pitch track을 고름 | 다른 tracker와 구현/설정이 달라 pYIN이 항상 정확하거나 느린 것은 아님 | 현재 YIN의 시계열 안정성 문제가 확인되면 동일 입력 대조군 |
| 신경망 F0 | 학습된 모델로 넓은 음색·잡음 조건을 다룰 수 있음 | 학습 자료-마이크 조건 차이, 추론 주기·CPU·모델 배포 검증 필요 | 재현된 실패가 단순 DSP로 해결되지 않을 때 조사 |
| 다중 F0/자동 전사 | 여러 음을 동시에 추정하고 음표 이벤트로 만들 수 있음 | 첫 단음 과제에는 과도하며 정확성·지연·전사 복잡성 문제를 추가 | 코드/곡 입력을 별도 조사할 때 |

YIN의 원 논문은 음성과 음악의 단음 기본주파수 추정을 다룬다. 그 결과는 이 앱의 특정 iPhone·기타·환경에서의 정확도 수치가 아니다. MPM 논문도 단음 musical sounds를 목표로 하므로, 기타에서 어느 쪽이 나은지는 동일 입력 자료로 판단한다.

기타 신호를 직접 다룬 2010 DAFx 비교 연구는 dry electric guitar의 단음 연주에서 YIN을 실시간 단음 기타 추적의 적절한 후보로 결론 내렸지만, 실제 녹음에서 옥타브 점프·주파수 흔들림도 확인했다. 테스트 신호의 일부는 합성·전기기타 기반이므로 스마트폰 마이크로 받은 어쿠스틱 기타 결과라고 볼 수 없다. 2016년 DAFx 비교는 pYIN을 IDMT-SMT-GUITAR의 단음 lick 자료로 평가해 F-measure 88.23%를 보고했고, 비교한 추적기 중 onset에 빠르게 반응했다고 기록했다. 따라서 pYIN을 일괄적으로 느리다고 단정하지 않는다. 해당 수치는 연구 데이터·평가기준·설정에 한정된다. 이 자료는 “YIN이 현재 첫 기준선으로 타당하다”는 근거를 보태지만, 알고리즘 교체 결론은 제공하지 않는다.

신경망 후보의 예로 2025년 공개된 [SwiftF0 사전 공개 논문](https://arxiv.org/abs/2508.18440)은 95,842개 파라미터의 단음 F0 모델과 여러 음성·음악·합성 자료의 비교를 제시한다. 저자가 보고한 10 dB SNR 결과와 desktop CPU 시간은 이 앱 iPhone/어쿠스틱 기타 입력 수치가 아니다. 데이터 구성도 연주실의 휴대폰 기타 녹음을 대신하지 않으므로, 후보 조사 대상으로만 기록한다.

## 판정 파이프라인 권고

```text
프레임 수집 → 무음/약한 입력 거절 → F0 후보 + confidence
            → 시간상 신선도 확인 → MIDI/목표 음 비교
            → 안정 프레임 조건 충족 시 정답/다른 음 상태 전달
```

- 타깃의 현과 프렛이 알려져 있으므로, 추정 주파수를 가장 가까운 MIDI 음으로만 반올림하지 말고 목표 음 주파수와 비교한다.
- 시작 타격 직후의 불안정 프레임이 오답을 만들지 않도록 clarity와 짧은 지속 조건을 둔다. 대기 시간이 늘어나는 비용도 같이 측정한다.
- “소리가 안 들림”과 “다른 음을 침”은 별도 상태로 둔다. 낮은 clarity 결과를 틀린 음으로 취급하지 않는다.
- 제품 계획의 ±50 cent 정답 허용치는 DAFx 2016의 pYIN 평가에서 pitch detection precision/recall 기준을 만들 때 사용한 오차 폭과 일치한다. 이것은 비교 가능한 연구 기준임을 뒷받침하지만, 초보 연습의 교육적 정답 기준을 증명하는 것은 아니다. 실기기 안정성·오답 체감을 같이 본다.
- 센트 오차는 연속 튜너 UI에는 유용하지만, 초급 프렛 과제의 핵심 피드백은 음이 맞는지와 다시 쳐야 하는지다. 센트 표시를 제품 UI에 노출할지는 별도 UX 결정이다.
- 과제 이벤트는 의도한 현·프렛을 표시하지만 마이크 음정 판정만으로 같은 pitch를 만드는 대체 포지션을 구별할 수 없다. 화면 운지 지시는 유지하고 오디오 결과를 exact fingering 검증처럼 표현하지 않는다.

## 비교 실험

초기 비교는 현재 YIN 단독으로 시작한다. `비행기`의 C4–A4 목표음, 반복 C4/G4/A4, 약한 타격, 잡음, 현 버징, 강한 2차 배음, 발음 직후, 잔향을 나눈다. 각 항목의 라벨 음을 정하고 다음을 기록한다.

- 목표 음 정답률, 다른 음 오분류율, 무응답률
- 옥타브 오류율 및 프레임별 편향
- 첫 타격부터 안정된 판정까지의 지연 p50/p95
- 연속 프레임 간 주파수 흔들림
- CPU와 입력 중단 여부

YINFFT/MPM은 기준선이 특정 오류를 보일 때 같은 녹음·실시간 프레임으로 비교한다. 평균 오차 하나로 정하지 않고 사용자에게 보이는 오답·무응답 유형을 우선한다.

## 참고

- de Cheveigné & Kawahara, [YIN (2002)](https://pubmed.ncbi.nlm.nih.gov/12002874/)
- McLeod & Wyvill, [A Smarter Way to Find Pitch (ICMC 2005)](https://www.cs.otago.ac.nz/graphics/Geoff/tartini/papers/A_Smarter_Way_to_Find_Pitch.pdf)
- von dem Knesebeck & Zölzer, [Comparison of Pitch Trackers for Real-Time Guitar Effects (DAFx 2010)](https://dafx10.iem.at/papers/VonDemKnesebeckZoelzer_DAFx10_P102.pdf): 단음 dry electric guitar, 정확도·지연 비교.
- Böhler & Zölzer, [Monophonic Pitch Detection by Evaluation of Individually Parameterized Phase Locked Loops (DAFx 2016)](https://www.dafx.de/paper-archive/2016/dafxpapers/35-DAFx-16_paper_22-PN.pdf): IDMT-SMT-GUITAR 단음 자료에서 pYIN 등과 비교.
- aubio, [pitch and onset analysis API](https://aubio.org/manual/latest/py_analysis.html), [pitch method descriptions](https://aubio.org/manual/latest/cli.html)
- Spotify, [Basic Pitch overview](https://engineering.atspotify.com/2022/06/meet-basic-pitch): 전사 및 폴리포닉 모델을 검토할 때의 비교점. 첫 단음 과제에 채택한다는 뜻은 아니다.
