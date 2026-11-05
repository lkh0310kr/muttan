# 음 시작점과 리듬 정렬

현재 `PitchDetector.estimate`는 한 샘플 배열에서 주파수·clarity 하나를 반환하고 타격 시각/구간을 반환하지 않는다. `TunerView`의 4096프레임 tap도 callback마다 버퍼 전체를 한 번 분석한다. 따라서 현재 튜너에 같은 음을 여러 번 쳐도 각각의 onset을 식별하는 기능이 있다고 볼 수 없으며, 연습 기능은 onset detector나 변화 이벤트를 별도로 추가해야 한다.

## 왜 음정 추정과 나누는가

피치 추정은 한 구간에서 어떤 음높이가 울리는지를 찾는다. 온셋(onset)은 새로운 타격이 시작된 때를 찾는다. 같은 현에서 같은 프렛을 연달아 치면 음높이는 바뀌지 않으므로, 음정값만 비교해서는 두 타격을 구분할 수 없다. 짧은 `0, 0, 1, 1` 패턴은 onset 검출과 과제 타임라인을 따로 설계해야 한다.

## 점진적 접근

1. **현재 곡 시제품:** 알려진 12마디 이벤트 타임라인에서 목표 음이 맞는지와 새 타격이 시작됐는지를 함께 판정한다. 동일 pitch 반복 이벤트가 있으므로 onset은 핵심 신호다.
2. **반복음:** RMS/에너지 상승과 재검출 최소 간격을 단순 기준선으로 구현·측정한다. 지속음에서 중복, 약한 재타격에서 누락되는지 본다.
3. **정확한 리듬:** 온셋 시각과 단조 증가 시계 기반 beat clock을 비교한다. 입력 지연과 사용자의 타이밍 오차를 별도로 표시한다.
4. **복잡한 패턴:** 단순 에너지 기준이 실패한 케이스에 한해 spectral flux나 복합 onset novelty를 평가한다.

## 서로 다른 분석 창

온셋과 음높이는 다른 질문이므로 한 callback마다 4096샘플 전체의 pitch만 구하는 방식이 타격 시각과 빠른 반응을 동시에 제공하지 않는다. 비교할 설계는 짧은 hop으로 RMS/flux 변화를 찾는 경로와, 더 긴 sliding window에서 F0를 확인하는 경로를 분리한다.

```text
capture ring → short window/hop → candidate onset + capture time
            → longer pitch window(s) → F0 + clarity
            → same event ID/time window → expected note + beat decision
```

- Onset 경로가 빠르더라도 pitch가 안정될 때까지 해당 event를 `pending`으로 두고, 그 전의 noise spike로 오답을 확정하지 않는다.
- Pitch 경로가 여러 결과를 내더라도 onset 하나당 이벤트 진행은 최대 한 번만 허용한다.
- 작은 에너지 window는 빠르지만 손가락·현 잡음에 취약할 수 있다. 더 잦은 sliding analysis는 CPU와 샘플 관리 비용을 높이므로 2048/4096 F0 window 및 256/512 hop 후보를 실기기에서 측정한다.
- 동일 음 반복이 아닌 서로 다른 음 이벤트에서는 pitch 변화가 onset 근거를 보강하지만, 해당 변화를 onset 그 자체로 쓰지 않는다.

## 후보 기법

- **RMS/에너지 envelope:** 계산량이 적고 타격에 따른 에너지 상승을 찾기 쉽다. 노이즈·손가락 소리·진동 중인 현의 에너지 변화도 이벤트처럼 보일 수 있다.
- **Spectral flux:** 인접 프레임 사이 스펙트럼 변화량으로 새로운 에너지를 감지한다. 에너지 문턱이 놓치는 약한 타격의 후보지만 프레임 간격, 임계값, 기타 배음 변화에 맞춘 검증이 필요하다.
- **복합 novelty 함수:** spectral sparsity 등 여러 특징을 결합해 온셋을 더 구별하려는 연구가 있다. 구현과 튜닝 비용이 크므로 단순 baseline 이후 선택한다.
- **재검출 억제 시간(refractory/minimum inter-onset interval):** 중복 타격을 줄이지만 빠른 연타를 합쳐 버릴 수 있다. 기본값을 관행으로 정하지 말고 목표 최대 템포에서 측정한다.

aubio는 energy, spectral flux를 포함한 여러 onset 방식과 최소 온셋 간격 설정을 제공한다. 이는 알고리즘 옵션을 확인하는 근거이지, 앱에 라이브러리 추가를 권하는 것은 아니다.

기타 온셋에 특화된 NINOS² 연구는 스펙트럼의 희소도가 타격부와 지속부에서 달라지는 점을 활용한다. 2016년 연구는 자동 주석을 붙인 기타 멜로디와 코드 진행에서 LogFiltSpecFlux와 비교했다. 2021년 후속 평가는 현악기·반복음·비브라토 등 시나리오를 넓혔으며 sustained-strings 그룹에서 제안 특징이 baseline보다 좋은 결과를 보였지만, 결과는 데이터셋마다 달랐다. 따라서 고급 검출기의 존재만으로 초보의 단일 현 재타격 문제에 바로 적용할 이유가 되지는 않는다. 우선 실제 앱 입력에서 에너지 기준선이 실패하는 유형을 만들고, 그 입력과 가까운 검증 자료를 사용해야 한다.

## 타이밍 모델과 UX

- 음원·악보가 앱이 만든 짧은 패턴이면 템포 추정이 필요 없다. 기준 박을 앱이 정하고 사용자 onset과 비교한다.
- 각 과제 이벤트는 `target onset`, `pitch`, `string`, `fret`, note duration, 허용 timing window를 가진다. 12마디 단곡 데이터는 작은 자체 이벤트 모델로 충분하다.
- `Date` 시계 변경에 흔들리지 않도록 세션 내 경과 시간은 단조 시계로 계산한다.
- 늦은 입력 분석이 이미 지난 이벤트를 오답 처리하지 않도록 캡처된 오디오 시각 기준으로 매칭한다.
- 시제품 계획은 오답 후 약 300ms, 이벤트 시작점 1.5초 전으로 이동, 2박 카운트인 후 자동 재개를 요구한다. 오디오 재생 전체가 아닌 이벤트 playhead와 기준 시계의 재설정으로 구현하는 방식이 단순하다. 사용자 기대와 일치하는지 실제 화면·오디오로 확인하고 필요할 때 제품 계획을 조정한다.
- 타격이 없을 때는 오답음으로 판정하지 않는다. timeout 시 재생/대기/직접 재시도 중 다음 상태를 분명히 보여준다.

## 측정 항목

라벨한 타격 시각 대비 검출 지연, 반복음 누락률, 중복률, 배경 잡음 오검출률, 의도한 최단 타격 간격에서의 재현율, 오디오 처리 지연 p95를 기록한다. 음정 판정률과 onset 판정률을 따로 집계해 어느 단계에서 문제가 생겼는지 분리한다.

## 참고

- [Musical note onset detection based on a spectral sparsity measure](https://pmc.ncbi.nlm.nih.gov/articles/PMC8550344/): 현악기 자료를 포함한 onset 연구.
- Mounir et al., [Guitar note onset detection based on a spectral sparsity measure (EUSIPCO 2016)](https://www.eurasip.org/Proceedings/Eusipco/Eusipco2016/papers/1570256369.pdf): 기타 멜로디·코드 진행의 NINOS² 비교.
- Mounir et al., [Musical note onset detection based on a spectral sparsity measure (2021)](https://link.springer.com/article/10.1186/s13636-021-00214-7): 다양한 악기·연주·혼합 자료 비교와 한계.
- aubio, [analysis API](https://aubio.org/manual/latest/py_analysis.html), [CLI onset methods](https://aubio.org/manual/latest/cli.html): energy, spectral flux 및 기타 novelty 방식 개요.
