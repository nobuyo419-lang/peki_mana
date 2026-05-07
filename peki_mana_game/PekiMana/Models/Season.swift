// Season.swift — 季節判定
import Foundation
import SwiftUI

enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    static var current: Season {
        let m = Calendar.current.component(.month, from: Date())
        switch m {
        case 3...5:  return .spring
        case 6...8:  return .summer
        case 9...11: return .autumn
        default:     return .winter
        }
    }

    var label: String {
        switch self {
        case .spring: return "春"
        case .summer: return "夏"
        case .autumn: return "秋"
        case .winter: return "冬"
        }
    }

    var skyTop: Color {
        switch self {
        case .spring: return Color(red: 1.0, green: 0.86, blue: 0.93)
        case .summer: return Color(red: 0.55, green: 0.82, blue: 0.98)
        case .autumn: return Color(red: 1.0, green: 0.78, blue: 0.55)
        case .winter: return Color(red: 0.78, green: 0.86, blue: 0.96)
        }
    }

    var skyBottom: Color {
        switch self {
        case .spring: return Color(red: 1.0, green: 0.96, blue: 0.98)
        case .summer: return Color(red: 0.85, green: 0.95, blue: 1.0)
        case .autumn: return Color(red: 1.0, green: 0.92, blue: 0.78)
        case .winter: return Color(red: 0.96, green: 0.97, blue: 1.0)
        }
    }

    var groundColor: Color {
        switch self {
        case .spring: return Color(red: 0.62, green: 0.78, blue: 0.45)
        case .summer: return Color(red: 0.55, green: 0.75, blue: 0.42)
        case .autumn: return Color(red: 0.78, green: 0.62, blue: 0.38)
        case .winter: return Color(red: 0.92, green: 0.94, blue: 0.97)
        }
    }
}
