# 코드와 스트럼 인식

## 서로 다른 세 가지 목표

| 목표 | 출력 | 단순 접근 | 주된 한계 |
| --- | --- | --- | --- |
| 코드 이름 인식 | 예: G major, D minor | chord window에서 pitch-class profile/chroma와 제한된 코드 템플릿 비교 | 배음·누락음·다른 악기 영향, 윈도 경계와 코드 전환 중 혼합 |
| 운지/보이싱 추정 | 문자열마다 현·프렛 또는 inversion | 다중 F0 + 악기 물리 제약/타브 후보 최적화; 영상 단서 병합 연구도 존재 | 같은 화음이 여러 위치에서 가능하고 같은 음높이도 여러 현에서 연주 가능 |
| 스트럼 이벤트 인식 | 타격 시점, down/up 방향, 리듬 패턴 | onset + 스펙트럼/에너지 변화 + 저주파/고주파 진행 특성 | 빠른 스트럼이 겹치고 현·손톱·바디 타격이 섞임; 마이크 위치/기타 음색에 민감 |

사용자가 코드 이름을 맞게 냈는지 알려주는 기능이라면 첫 단계는 운지를 식별하지 않아도 된다. “이 코드 소리가 맞나?”와 “손가락을 정확히 어디에 놓았나?”를 한 모델의 출력으로 뭉치지 않는다.

## 기술 갈래

1. **chroma/PCP 템플릿 분류:** 스펙트럼의 음고를 12개 pitch class로 모으고, 후보 코드의 구성음과 비교한다. 제한된 초급 코드 사전이라면 후보 선택형 분류가 일반 다중 음 전사보다 좁은 문제다. 그러나 코드 타격 직후 또는 잔향에서는 여러 순간이 섞이므로 안정 구간 선택이 필요하다.
2. **다중 F0 추정:** 각 프레임에서 동시에 울리는 여러 기본음을 찾는다. 각 음을 분리해 정확한 현·프렛 위치까지 복원하는 것은 별도의 역문제다. 기타 프렛보드의 동일 음/코드 대체 운지가 이를 모호하게 만든다.
3. **학습 기반 오디오 분류/전사:** Basic Pitch는 파일을 받아 복수 음의 onset/frame을 MIDI 이벤트로 만드는 Automatic Music Transcription 모델이며 Core ML 모델 포맷도 제공한다. 공식 Python interface는 audio file prediction 중심이다. 범용 전사 출력을 곧바로 코드 정답 또는 운지 정답으로 취급하지 않는다. 실시간 마이크 응답·입력 잡음·iOS streaming inference와 추론비용은 이 앱에서 별도 확인해야 한다.
4. **온셋 기반 스트럼 이벤트:** 먼저 각 스트럼의 타격 시각을 검출한 다음 패턴의 타이밍과 맞춘다. down/up 방향 판단은 별도 출력 목표로 둔다. GuitarSet은 리듬 스타일·연주 표기 및 스트럼 기술이 포함된 유용한 공개 연구 데이터지만, 스마트폰 정면 마이크 입력 조건의 완전한 대표 데이터는 아니다.

## 공개 평가 자료

- **GuitarSet:** 어쿠스틱 기타 발췌 360개, 음고 곡선·현/프렛·코드·박/강박·연주 스타일 주석을 제공한다. hexaphonic pickup으로 개별 현 신호를 얻어 주석 작업을 지원했고 별도 마이크 녹음도 포함한다. 구조화된 비교 자료지만 장르/연주자/녹음 환경 범위가 제한적이므로 실제 iPhone 테스트를 대체하지 않는다. 파일 이용 조건과 저장소의 알려진 주석 오류도 확인한다.
- **IDMT-SMT-GUITAR:** Fraunhofer 설명에 따르면 다양한 표준 튜닝 기타, 모노·폴리포닉 노트와 코드 인식/리듬 평가용 excerpt가 있다. 기타 픽업/직접 입력을 포함한 자료는 폰의 공기 전달 음향과 다른 음색을 낼 수 있다.
- 두 자료는 알고리즘 프로토타입을 재현하는 데 유용하다. 제품 적합성은 같은 과제 패턴을 실기기에서 녹음해 보충한다.

## 이 앱에서의 권장 진행

1. **현재 첫 과제:** `연습` 탭의 0–1–2–3 단음 훈련과 `곡` 탭의 `비행기`에서 정의된 음 타깃을 F0/onset 및 BPM 타임라인에 맞춘다. 화음 인식은 사용하지 않는다.
2. **후속 코드 연습:** 앱이 제시한 후보 코드 2–4개를 구분하는 chord template/chroma baseline을 검토한다. 정확한 fingering UI 피드백이 요구되지 않는 한 운지 분류를 추가하지 않는다.
3. **후속 스트럼 리듬:** 실험용 drum/metronome beat 기준으로 onset 타이밍 평가부터 한다. 방향 인식은 사용자 요구와 baseline 실패가 확인된 뒤에 별도 조사한다.
4. **이후 곡 재생·반주:** polyphonic 전사보다 미리 정해진 곡 이벤트와 사용자 단음/코드 입력을 정렬하는 방식이 더 작은 문제인지 먼저 확인한다.

## 비교 기준

코드 이름의 precision/recall, 코드 전환 중 오답/지연, 무음/약한 코드의 무응답, onset 누락/중복, down/up 분류 정확도, 마이크에서 결과까지의 p95 지연, 세션 CPU/발열, 실기기와 공개셋 간 성능 차이를 별도로 기록한다. 코드가 바뀌는 순간을 오답 구간으로 세지 않도록 과제 타임라인과 안정화 구간을 명시한다.

## 참고

- Xi et al., [GuitarSet: A Dataset for Guitar Transcription (ISMIR 2018)](https://zenodo.org/records/3371780): 음고·운지·코드·박 주석과 데이터 설명.
- Fraunhofer IDMT, [Guitar datasets](https://www.idmt.fraunhofer.de/en/publications/datasets/guitar.html): 코드 및 리듬 평가용 기타 자료 개요.
- Hrybyk & Kim, [Combined Audio and Video Analysis for Guitar Chord Identification (ISMIR 2010)](https://researchdiscovery.drexel.edu/esploro/outputs/graduate/Combined-audio-and-video-analysis-for/991014632333704721): chord label과 실제 voicing/fingering 구분 및 오디오/비디오 접근.
- Spotify, [Basic Pitch overview](https://engineering.atspotify.com/2022/6/meet-basic-pitch), [source and paper links](https://github.com/spotify/basic-pitch): 다중음 MIDI 전사 모델의 범위.
- Mounir et al., [Guitar note onset detection based on a spectral sparsity measure (EUSIPCO 2016)](https://www.eurasip.org/Proceedings/Eusipco/Eusipco2016/papers/1570256369.pdf): 기타 온셋 연구 배경.
