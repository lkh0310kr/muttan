import SwiftUI

@main
struct MuttanApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        DebugLog.record("app.launch", details: [
            "system": ProcessInfo.processInfo.operatingSystemVersionString,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    DebugLog.record("app.scene", details: ["phase": String(describing: phase)])
                }
        }
    }
}
