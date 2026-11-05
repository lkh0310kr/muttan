# muttan

개인용 기타 튜닝 및 연습 도구 앱입니다. 제품 범위와 동작 요구사항은 [제품 명세](docs/PRD.md), UI 작업 기준과 조사 근거는 [디자인 가이드](docs/DESIGN_GUIDELINES.md)를 참고하세요. Xcode에서 `muttan.xcodeproj`를 열고 **muttan** scheme을 iOS 시뮬레이터나 기기에서 실행합니다.

코드 사전은 180개 코드·213개 운지를 카드 또는 코드표로 제공합니다. 근음·종류 필터와 이명동음 검색을 지원합니다. 마이크 입력을 사용하는 실시간 기타 튜너도 제공합니다. 음정 추정에는 YIN 방식과 신뢰도 필터링, 시간적 완화를 사용합니다. 진단 이벤트는 Apple Unified Logging에 기록됩니다. 기기 로그를 보려면 Xcode에서 연결된 iPhone에 **muttan** scheme을 실행하고 Debug console을 확인합니다. 설정 화면은 현재 프로토타입입니다.

## Capture UI screenshots

Run `./scripts/capture-ui-screenshots.sh` to build the app, launch each screen in light and dark appearance on a background iOS simulator, and save pairs such as `chords-light.png` and `chords-dark.png` to `artifacts/ui-screenshots/`. It automatically finds the Xcode project, uses the matching scheme, and reads the app bundle ID from the built product. Choose a simulator or customize screens and appearances with command-line options such as `--device-name 'iPhone 17'`, `--screens chords,tuner`, and `--appearances dark`. The tuner uses fixed preview data in this mode and never requests microphone access.

Available screenshot screens: `chords` (catalog), `chord-chart` (root-by-quality diagram chart), `chord-detail` (F barre voicing), `tuner`, `settings`. Run `python3 scripts/validate-chords.py` to validate all chord voicings.

Run `./scripts/check-models.sh` for chord search/note and tuner session/expiry/target regression checks, plus synthetic pitch checks at 44.1, 48 and 96 kHz. Real microphone routing and interruptions still require an iPhone check.

[코드 목록과 구성음](docs/chord-catalog.md)에서 15개 종류의 정의, 전체 코드표, 검색 별칭을 확인할 수 있습니다.
