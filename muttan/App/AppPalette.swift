import SwiftUI

extension Color {
    static let tunerSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.08, blue: 0.095, alpha: 1)
            : UIColor(red: 0.95, green: 0.955, blue: 0.95, alpha: 1)
    })

    /// Dark ink on light surfaces; a brighter accent on dark surfaces.
    static let instrumentAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.88, blue: 0.74, alpha: 1)
            : UIColor(red: 0, green: 0.40, blue: 0.34, alpha: 1)
    })
}
