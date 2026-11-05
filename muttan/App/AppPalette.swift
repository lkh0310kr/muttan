import SwiftUI

extension Color {
    /// Dark ink on light surfaces; a brighter accent on dark surfaces.
    static let instrumentAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.88, blue: 0.74, alpha: 1)
            : UIColor(red: 0, green: 0.40, blue: 0.34, alpha: 1)
    })
}
