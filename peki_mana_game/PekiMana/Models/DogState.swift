// DogState.swift — ゲーム状態のモデルと永続化
import Foundation
import SwiftUI

enum AffectionStage: Int, Codable, CaseIterable, Comparable {
    case wary, familiar, trust, loving, spoiled

    static func < (a: AffectionStage, b: AffectionStage) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .wary:     return "警戒"
        case .familiar: return "慣れ"
        case .trust:    return "信頼"
        case .loving:   return "親愛"
        case .spoiled:  return "甘えん坊"
        }
    }

    var description: String {
        switch self {
        case .wary:     return "まだ少し怖がっています。優しく見守って。"
        case .familiar: return "あなたの存在に慣れてきました。"
        case .trust:    return "あなたを信頼しています。"
        case .loving:   return "あなたが大好き。尻尾を振って迎えます。"
        case .spoiled:  return "甘えん坊全開。べったり離れません。"
        }
    }

    static func from(affection: Double) -> AffectionStage {
        switch affection {
        case ..<20:  return .wary
        case ..<40:  return .familiar
        case ..<65:  return .trust
        case ..<88:  return .loving
        default:     return .spoiled
        }
    }
}

enum DogPose: String, Codable {
    case stand, sit, lie, sleep, jump, walk, beg
}

enum TimeOfDay: String, Codable {
    case morning, noon, evening, night

    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<11:  return .morning
        case 11..<16: return .noon
        case 16..<20: return .evening
        default:      return .night
        }
    }

    var label: String {
        switch self {
        case .morning: return "朝"
        case .noon:    return "昼"
        case .evening: return "夕方"
        case .night:   return "夜"
        }
    }
}

struct DogState: Codable {
    var name: String = "マナ"

    // 0..100
    var affection: Double = 8
    var hunger: Double = 35       // 高いほど空腹
    var energy: Double = 90
    var cleanliness: Double = 90
    var toiletMastery: Double = 0 // 0..100
    var trickProgress: [String: Double] = [:]
    var unlockedTricks: Set<String> = ["sit"]

    var dayCount: Int = 1
    var totalActions: Int = 0
    var pottyAccidents: Int = 0
    var pottySuccess: Int = 0
    var walks: Int = 0
    var baths: Int = 0
    var meals: Int = 0
    var treats: Int = 0
    var brushings: Int = 0

    var isAsleep: Bool = false
    var lastUpdated: Date = Date()
    var bornAt: Date = Date()

    var endingClaimed: String? = nil
    var seenIntro: Bool = false

    // ----- 派生プロパティ -----
    var stage: AffectionStage { AffectionStage.from(affection: affection) }

    var ageInDays: Int { dayCount }

    var moodFace: String {
        if isAsleep { return "zzz" }
        if hunger > 75 { return "hungry" }
        if energy < 20 { return "tired" }
        if cleanliness < 25 { return "dirty" }
        if affection > 70 { return "happy" }
        return "neutral"
    }

    /// 表情・尻尾の振り速度などに使う 0..1
    var liveliness: Double {
        let e = max(0, min(100, energy)) / 100
        let a = max(0, min(100, affection)) / 100
        return (e * 0.4 + a * 0.6)
    }

    /// なつき度に応じた歓迎倍率
    var welcomeBoost: Double {
        switch stage {
        case .wary:     return 0.4
        case .familiar: return 0.7
        case .trust:    return 1.0
        case .loving:   return 1.2
        case .spoiled:  return 1.4
        }
    }
}

extension DogState {
    static let saveKey = "PekiMana.DogState.v1"

    static func load() -> DogState {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let s = try? JSONDecoder().decode(DogState.self, from: data) {
            return s
        }
        return DogState()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }
}
