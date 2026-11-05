# Simply Guitar · 기술

## 공개 근거

Simply의 공식 인식 도움말은 리드 연주에서 올바른 줄을 확인하라고 하고, 연주 음이 충분히 울리도록 유지하라고 권한다. 곡의 리듬 영역에서는 앱의 배경음이 마이크에 들어오지 않도록 헤드폰을 권한다. 이를 통해 제품이 실시간 악기 오디오를 입력으로 받고 음·코드 수행에 피드백을 제공한다는 점을 확인할 수 있다.

마이크 권한 문제는 iOS 개인정보 설정과 앱별 권한을 확인하도록 안내한다. 사용자는 조용한 장소, 기타 튜닝, 기기 마이크 가림 여부와 음량을 점검한다.

## 확인되지 않은 구현

내부 인식 알고리즘, 오디오가 기기 안에서만 처리되는지, 클라우드 사용 여부, 온셋·리듬 점수 계산식, 주파수 오차 허용값, 오답 시 자동 정지·되감기 동작은 공개 도움말에서 밝히지 않는다. `YIN`, FFT, 기계학습 모델 등을 사용한다고 추론하지 않는다.

### 근거

- [Simply Guitar 인식 개선](https://piano-help.hellosimply.com/en/articles/5135082-improve-note-recognition-in-simply-guitar)
- [Simply Guitar 마이크 권한](https://piano-help.hellosimply.com/en/articles/5834411-enable-microphone-access-for-simply-guitar)
