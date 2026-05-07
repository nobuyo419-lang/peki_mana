// GameStorage.swift — ゲーム状態のObservableObjectラッパー
import Foundation
import SwiftUI
import Combine

@MainActor
final class DogStore: ObservableObject {
    @Published var dog: DogState
    @Published var lastEvent: GameEvent? = nil

    init() {
        self.dog = DogState.load()
        applyTimePassed()  // 起動時に経過時間で状態減衰
    }

    // ===== 永続化 =====
    func persist() { dog.save() }

    func resetAll() {
        DogState.reset()
        dog = DogState()
        persist()
    }

    // ===== ログ =====
    func event(_ text: String, kind: GameEvent.Kind = .info) {
        lastEvent = GameEvent(text: text, kind: kind, at: Date())
    }

    // ===== 時間経過 =====
    /// 起動時/復帰時に呼んで、経過時間に応じてステータスを減衰
    func applyTimePassed() {
        let now = Date()
        let dt = max(0, now.timeIntervalSince(dog.lastUpdated))
        // 上限: 6時間まで反映(放置しすぎても瀕死にしない)
        let cappedHours = min(dt / 3600.0, 6.0)
        if cappedHours > 0.05 {
            dog.hunger = clamp(dog.hunger + cappedHours * 6.0)
            dog.energy = clamp(dog.energy - cappedHours * 4.0)
            dog.cleanliness = clamp(dog.cleanliness - cappedHours * 1.5)
            // 一日経過判定
            let elapsedDays = Int(dt / (60 * 60 * 24))
            if elapsedDays > 0 {
                dog.dayCount += elapsedDays
            }
        }
        dog.lastUpdated = now
        persist()
    }

    // ===== アクション =====

    func pet() {
        guard !dog.isAsleep else {
            event("マナはぐっすり眠っています…", kind: .info); return
        }
        let gain = 1.5 * dog.welcomeBoost
        dog.affection = clamp(dog.affection + gain)
        dog.energy = clamp(dog.energy - 0.4)
        dog.totalActions += 1
        event("マナを撫でた。\(dog.stage == .wary ? "少し緊張しているようだ。" : "嬉しそう。")", kind: .affection)
        persist()
    }

    func feedMeal() {
        guard !dog.isAsleep else { event("眠っています", kind: .info); return }
        if dog.hunger < 15 {
            event("おなかいっぱい。今は食べたくないみたい。", kind: .info)
            return
        }
        dog.hunger = clamp(dog.hunger - 45)
        dog.affection = clamp(dog.affection + 1.2 * dog.welcomeBoost)
        dog.energy = clamp(dog.energy + 6)
        dog.cleanliness = clamp(dog.cleanliness - 2)
        dog.meals += 1
        dog.totalActions += 1
        // トイレを覚えていない時期はおもらしリスク
        maybePottyAccident(after: 0.7)
        event("ごはんをあげた。もぐもぐ。", kind: .care)
        persist()
    }

    func giveTreat() {
        guard !dog.isAsleep else { event("眠っています", kind: .info); return }
        dog.affection = clamp(dog.affection + 2.5 * dog.welcomeBoost)
        dog.hunger = clamp(dog.hunger - 8)
        dog.treats += 1
        dog.totalActions += 1
        event("おやつをあげた。尻尾フリフリ。", kind: .affection)
        persist()
    }

    func walk() {
        guard !dog.isAsleep else { event("眠っています", kind: .info); return }
        if dog.energy < 20 {
            event("マナは疲れているようだ。少し休ませよう。", kind: .info); return
        }
        dog.energy = clamp(dog.energy - 18)
        dog.hunger = clamp(dog.hunger + 12)
        dog.cleanliness = clamp(dog.cleanliness - 14)
        dog.affection = clamp(dog.affection + 3.5 * dog.welcomeBoost)
        dog.toiletMastery = clamp(dog.toiletMastery + 4)  // 屋外排泄で習熟
        dog.walks += 1
        dog.totalActions += 1
        event("散歩に行った。気持ちよさそう。", kind: .affection)
        persist()
    }

    func bath() {
        guard !dog.isAsleep else { event("眠っています", kind: .info); return }
        let resist = dog.stage <= .familiar
        dog.cleanliness = 100
        dog.energy = clamp(dog.energy - 8)
        if resist {
            dog.affection = clamp(dog.affection - 1.0)
            event("お風呂は苦手みたい。ちょっと嫌がっていた。", kind: .info)
        } else {
            dog.affection = clamp(dog.affection + 0.6)
            event("お風呂さっぱり。ふわふわになった。", kind: .care)
        }
        dog.baths += 1
        dog.totalActions += 1
        persist()
    }

    func sleep() {
        if dog.isAsleep {
            // 起こす
            dog.isAsleep = false
            dog.energy = clamp(dog.energy + 50)
            event("マナが目を覚ました。", kind: .info)
        } else {
            dog.isAsleep = true
            event("マナは眠りについた…", kind: .info)
        }
        persist()
    }

    func brush(strokes: Int) {
        let inc = Double(strokes) * 0.6
        dog.cleanliness = clamp(dog.cleanliness + inc)
        dog.affection = clamp(dog.affection + Double(strokes) * 0.15 * dog.welcomeBoost)
        dog.brushings += 1
        dog.totalActions += 1
        event("ブラッシング完了。毛がふわふわ。", kind: .care)
        persist()
    }

    /// 芸の練習。成功率はなつき度・空腹・体力に依存
    @discardableResult
    func practice(trick: Trick) -> Double {
        guard trick.isUnlocked(in: dog) else { return 0 }
        guard !dog.isAsleep else { event("眠っています", kind: .info); return 0 }
        if dog.energy < trick.energyCost + 3 {
            event("マナは疲れていてうまく集中できない。", kind: .info); return 0
        }
        let baseFactor = 0.45 + dog.welcomeBoost * 0.4
        let hungerFactor = dog.hunger > 70 ? 0.4 : 1.0  // 空腹だと集中切れ
        let gain = trick.baseProgressGain * baseFactor * hungerFactor
        let cur = dog.trickProgress[trick.id] ?? 0
        dog.trickProgress[trick.id] = clamp(cur + gain)
        dog.energy = clamp(dog.energy - trick.energyCost)
        dog.affection = clamp(dog.affection + 0.6 * dog.welcomeBoost)
        dog.totalActions += 1

        // 50%到達で次の芸を解放
        for t in Trick.all where t.prerequisite == trick.id {
            if (dog.trickProgress[t.id] ?? 0) == 0,
               (dog.trickProgress[trick.id] ?? 0) >= 50,
               dog.stage >= t.unlockAffection {
                dog.unlockedTricks.insert(t.id)
                event("「\(t.label)」を覚える準備ができた。", kind: .achievement)
            }
        }

        if (dog.trickProgress[trick.id] ?? 0) >= 100 {
            event("「\(trick.label)」をマスターした。", kind: .achievement)
        } else {
            event("「\(trick.label)」を練習した。", kind: .care)
        }
        persist()
        return gain
    }

    /// トイレ訓練を直接(おすわりトイレ呼び)
    func toiletTrain() {
        guard !dog.isAsleep else { event("眠っています", kind: .info); return }
        let success = Double.random(in: 0..<1) < (0.25 + dog.toiletMastery / 200 + dog.welcomeBoost * 0.1)
        if success {
            dog.toiletMastery = clamp(dog.toiletMastery + 7)
            dog.affection = clamp(dog.affection + 0.6 * dog.welcomeBoost)
            dog.pottySuccess += 1
            event("トイレで上手にできた。たくさん褒めてあげよう。", kind: .achievement)
        } else {
            dog.pottyAccidents += 1
            dog.cleanliness = clamp(dog.cleanliness - 8)
            // しかりすぎると逆効果なので、むしろ覚えるチャンス
            dog.toiletMastery = clamp(dog.toiletMastery + 2)
            event("間に合わなかった…焦らず教えていこう。", kind: .info)
        }
        dog.totalActions += 1
        persist()
    }

    private func maybePottyAccident(after probability: Double) {
        let mastery = dog.toiletMastery / 100
        let p = probability * (1 - mastery) * 0.5
        if Double.random(in: 0..<1) < p {
            dog.cleanliness = clamp(dog.cleanliness - 6)
            dog.pottyAccidents += 1
            event("おもらししちゃった。優しくお片付けしよう。", kind: .info)
        }
    }

    /// 1日経過(サイクル)を進める
    func advanceDay() {
        dog.dayCount += 1
        dog.energy = clamp(dog.energy + 30)
        dog.hunger = clamp(dog.hunger + 25)
        if dog.cleanliness < 30 {
            dog.affection = clamp(dog.affection - 0.8)
        }
        persist()
    }

    // ===== エンディング判定 =====
    var availableEnding: Ending? {
        if dog.dayCount < 7 { return nil }  // 最低7日
        // 一度クリア済みなら再表示しない
        if let _ = dog.endingClaimed { return nil }
        return Ending.evaluate(dog: dog)
    }

    func claimEnding(_ e: Ending) {
        dog.endingClaimed = e.id
        persist()
    }
}

struct GameEvent: Identifiable {
    enum Kind { case info, affection, care, achievement }
    let id = UUID()
    let text: String
    let kind: Kind
    let at: Date
}

@inline(__always)
func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 100) -> Double {
    min(hi, max(lo, v))
}

// ===== エンディング =====
struct Ending: Identifiable {
    let id: String
    let title: String
    let body: String

    static func evaluate(dog: DogState) -> Ending {
        let mastered = Trick.all.filter { (dog.trickProgress[$0.id] ?? 0) >= 100 }.count
        let totalTrickProgress = Trick.all.reduce(0.0) { $0 + (dog.trickProgress[$1.id] ?? 0) }
        if dog.affection >= 95 && mastered >= 5 {
            return Ending(id: "champion",
                title: "名犬マナ",
                body: "深い信頼と豊富な芸を身につけたマナ。あなたとマナは最高のバディになりました。")
        }
        if dog.affection >= 90 {
            return Ending(id: "best_friend",
                title: "大親友エンド",
                body: "芸はそこそこ。でもマナはあなたの隣にいるだけで幸せそう。何ものにも代えがたい絆。")
        }
        if mastered >= 4 {
            return Ending(id: "trickster",
                title: "芸達者エンド",
                body: "賢く器用なマナ。たくさんの芸を覚えてみんなの人気者になりました。")
        }
        if dog.meals + dog.treats >= 40 && dog.walks <= 5 {
            return Ending(id: "gourmet",
                title: "グルメエンド",
                body: "ごはん大好きすぎたマナ。少し丸くなったけど、それも愛嬌。")
        }
        if dog.affection < 30 {
            return Ending(id: "shy",
                title: "シャイエンド",
                body: "マナはまだあなたに少し距離があるみたい。これからゆっくり仲良くなっていきましょう。")
        }
        if totalTrickProgress < 50 && dog.affection >= 60 {
            return Ending(id: "lazy",
                title: "ふわふわまったりエンド",
                body: "芸は得意じゃないけど、ふわふわのマナはいつもあなたを癒してくれます。")
        }
        return Ending(id: "ordinary",
            title: "ふつうエンド",
            body: "穏やかな日々。マナとの暮らしはこれからも続きます。")
    }
}
