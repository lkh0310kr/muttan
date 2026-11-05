# muttan

SwiftUI guitar-learning app starter. Open `muttan.xcodeproj` in Xcode and run the **muttan** scheme on an iOS simulator or device.

The app includes a practice home, live microphone tuner, progress view, settings, and diagnostic events recorded with Apple's Unified Logging. The tuner uses a YIN fundamental-frequency estimator with confidence rejection and temporal smoothing. For device debugging, run the **muttan** scheme on the connected iPhone in Xcode and inspect the Debug console.

## Capture UI screenshots

Run `./scripts/capture-ui-screenshots.sh` to build the app, launch each screen in light and dark appearance on a background iOS simulator, and save pairs such as `home-light.png` and `home-dark.png` to `artifacts/ui-screenshots/`. Set `DEVICE_NAME` to choose another installed simulator, or pass an output folder as the first argument. The tuner uses fixed preview data in this mode and never requests microphone access.
