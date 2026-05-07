// StatsBar.swift — 上部のステータスバー & 詳細シート
import SwiftUI

struct StatsBar: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.dog.name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(store.dog.stage.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(stageColor.opacity(0.85)))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.dog.dayCount)日目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: { audio.toggle() }) {
                    Image(systemName: audio.enabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                statPill("愛", value: store.dog.affection, color: .pink, icon: "heart.fill")
                statPill("食", value: 100 - store.dog.hunger, color: .orange, icon: "fork.knife")
                statPill("元", value: store.dog.energy, color: .green, icon: "bolt.fill")
                statPill("清", value: store.dog.cleanliness, color: .blue, icon: "sparkles")
                statPill("躾", value: store.dog.toiletMastery, color: .cyan, icon: "drop.fill")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
    }

    private var stageColor: Color {
        switch store.dog.stage {
        case .wary:     return .gray
        case .familiar: return .blue
        case .trust:    return .teal
        case .loving:   return .pink
        case .spoiled:  return .red
        }
    }

    private func statPill(_ label: String, value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            ProgressView(value: max(0, min(100, value)) / 100.0)
                .progressViewStyle(.linear)
                .tint(color)
                .frame(width: 40)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.7)))
        .accessibilityLabel("\(label): \(Int(value))")
    }
}

// MARK: - 詳細

struct StatsDetailView: View {
    @EnvironmentObject var store: DogStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("基本") {
                    detailRow("名前", store.dog.name)
                    detailRow("ステージ", "\(store.dog.stage.label) (\(Int(store.dog.affection))/100)")
                    detailRow("日数", "\(store.dog.dayCount) 日目")
                    detailRow("時間帯", TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date())).label)
                    detailRow("季節", Season.current.label)
                }
                Section("ステータス") {
                    bar("愛情", store.dog.affection, .pink)
                    bar("満腹度", 100 - store.dog.hunger, .orange)
                    bar("元気", store.dog.energy, .green)
                    bar("清潔さ", store.dog.cleanliness, .blue)
                    bar("トイレ習熟", store.dog.toiletMastery, .cyan)
                }
                Section("芸の習熟") {
                    ForEach(Trick.all) { t in
                        let v = store.dog.trickProgress[t.id] ?? 0
                        bar("\(t.label)", v, .purple)
                    }
                }
                Section("記録") {
                    detailRow("総アクション数", "\(store.dog.totalActions)")
                    detailRow("ごはん", "\(store.dog.meals)")
                    detailRow("おやつ", "\(store.dog.treats)")
                    detailRow("散歩", "\(store.dog.walks)")
                    detailRow("お風呂", "\(store.dog.baths)")
                    detailRow("ブラッシング", "\(store.dog.brushings)")
                    detailRow("トイレ成功", "\(store.dog.pottySuccess)")
                    detailRow("トイレ失敗", "\(store.dog.pottyAccidents)")
                }
                Section {
                    Button("セーブをリセット", role: .destructive) {
                        store.resetAll()
                        dismiss()
                    }
                }
            }
            .navigationTitle("ステータス")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }

    private func bar(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text("\(Int(value))/100")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: max(0, min(100, value)) / 100.0)
                .tint(color)
        }
    }
}
