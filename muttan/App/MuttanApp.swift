import SwiftUI

@main
struct MuttanApp: App {
    var body: some Scene {
        WindowGroup {
            AppTabView()
                .preferredColorScheme(.dark)
        }
    }
}
