import SwiftUI

extension HandbookCategory {
    var accentColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.18, green: 0.48, blue: 0.35)
        case .research:
            Color(red: 0.22, green: 0.40, blue: 0.74)
        case .meeting:
            Color(red: 0.76, green: 0.42, blue: 0.16)
        case .inspiration:
            Color(red: 0.50, green: 0.34, blue: 0.78)
        }
    }

    var softColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.90, green: 0.96, blue: 0.92)
        case .research:
            Color(red: 0.90, green: 0.94, blue: 1.0)
        case .meeting:
            Color(red: 1.0, green: 0.94, blue: 0.86)
        case .inspiration:
            Color(red: 0.95, green: 0.91, blue: 1.0)
        }
    }
}
