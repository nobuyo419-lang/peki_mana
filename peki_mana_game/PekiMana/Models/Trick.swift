// Trick.swift — 芸の定義と訓練ロジック
import Foundation

struct Trick: Identifiable, Hashable {
    let id: String
    let label: String
    let unlockAffection: AffectionStage
    let prerequisite: String?  // 別のtrickIDが習熟50以上で解放
    let baseProgressGain: Double
    let energyCost: Double
    let icon: String  // SF Symbol

    static let all: [Trick] = [
        Trick(id: "sit",   label: "お座り", unlockAffection: .wary,
              prerequisite: nil,    baseProgressGain: 12, energyCost: 6,  icon: "figure.seated.side"),
        Trick(id: "paw",   label: "お手",   unlockAffection: .familiar,
              prerequisite: "sit",  baseProgressGain: 10, energyCost: 7,  icon: "hand.raised.fill"),
        Trick(id: "down",  label: "伏せ",   unlockAffection: .familiar,
              prerequisite: "sit",  baseProgressGain: 9,  energyCost: 8,  icon: "arrow.down.to.line"),
        Trick(id: "wait",  label: "待て",   unlockAffection: .trust,
              prerequisite: "down", baseProgressGain: 7,  energyCost: 9,  icon: "pause.circle.fill"),
        Trick(id: "spin",  label: "お回り", unlockAffection: .trust,
              prerequisite: "paw",  baseProgressGain: 8,  energyCost: 10, icon: "arrow.clockwise"),
        Trick(id: "high5", label: "ハイタッチ", unlockAffection: .loving,
              prerequisite: "paw",  baseProgressGain: 6,  energyCost: 11, icon: "hands.sparkles.fill"),
    ]

    static func by(id: String) -> Trick? { all.first { $0.id == id } }
}

extension Trick {
    func isUnlocked(in dog: DogState) -> Bool {
        guard dog.stage >= unlockAffection else { return false }
        if let pre = prerequisite, (dog.trickProgress[pre] ?? 0) < 50 {
            return false
        }
        return true
    }

    var lockReason: String {
        if let pre = prerequisite, let p = Trick.by(id: pre) {
            return "「\(p.label)」を50%まで覚えると解放"
        }
        return "なつき度「\(unlockAffection.label)」で解放"
    }
}
