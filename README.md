# muttan

개인용 기타 튜닝 및 연습 도구 앱입니다. 제품 범위와 동작 요구사항은 [docs/PRD.md](docs/PRD.md)를 참고하세요. Xcode에서 `muttan.xcodeproj`를 열고 **muttan** scheme을 iOS 시뮬레이터나 기기에서 실행합니다.

현재 동작하는 핵심 기능은 마이크 입력을 사용하는 실시간 기타 튜너입니다. 음정 추정에는 YIN 방식과 신뢰도 필터링, 시간적 완화를 사용합니다. 진단 이벤트는 Apple Unified Logging에 기록됩니다. 기기 로그를 보려면 Xcode에서 연결된 iPhone에 **muttan** scheme을 실행하고 Debug console을 확인합니다. 홈·기록·설정 화면은 현재 프로토타입입니다.

## Capture UI screenshots

Run `./scripts/capture-ui-screenshots.sh` to build the app, launch each screen in light and dark appearance on a background iOS simulator, and save pairs such as `home-light.png` and `home-dark.png` to `artifacts/ui-screenshots/`. It automatically finds the Xcode project, uses the matching scheme, and reads the app bundle ID from the built product. Choose a simulator or customize screens and appearances with command-line options such as `--device-name 'iPhone 17'`, `--screens home,tuner`, and `--appearances dark`. The tuner uses fixed preview data in this mode and never requests microphone access.
