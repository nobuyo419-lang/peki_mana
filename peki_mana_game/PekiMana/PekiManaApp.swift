// PekiManaApp.swift
//
// ペキニーズ育成ゲーム「ペキマナ」 — iOS / SwiftUI
//
// =====================================================================
//  Xcode セットアップ手順
// =====================================================================
//  1. Xcode で新規プロジェクトを作成
//     File > New > Project > iOS > App
//      - Product Name: PekiMana
//      - Interface: SwiftUI
//      - Language: Swift
//      - Storage: None
//      - Minimum Deployment: iOS 17.0
//
//  2. デフォルトで生成された PekiManaApp.swift / ContentView.swift を削除
//
//  3. 本リポジトリの peki_mana_game/PekiMana/ 配下のファイルすべてを
//     Xcode プロジェクトのナビゲータにドラッグ&ドロップ
//      - "Copy items if needed" にチェック
//      - "Create groups" を選択
//      - Target: PekiMana にチェック
//
//  4. Signing & Capabilities で開発者アカウントを選択(実機ビルド時のみ)
//
//  5. iPhone シミュレータで Run (⌘R)
//
//  追加アセットは不要 — 犬・背景はすべて SwiftUI Canvas で手描き、
//  効果音は AVAudioEngine で合成しています。
// =====================================================================

import SwiftUI

@main
struct PekiManaApp: App {
    @StateObject private var dog = DogStore()
    @StateObject private var audio = AudioManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dog)
                .environmentObject(audio)
                .preferredColorScheme(.light)
        }
    }
}
