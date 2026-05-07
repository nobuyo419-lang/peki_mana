// TrainingView.swift — 芸の練習画面
import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss
    @State private var lastResult: String? = nil
    @State private var practicePose: DogPose = .sit

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundCanvas(season: Season.current,
                                 timeOfDay: TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date())))
                VStack(spacing: 14) {
                    DogCanvas(pose: practicePose, excited: false, size: 240)
                        .frame(maxWidth: .infinity)

                    if let r = lastResult {
                        Text(r)
                            .font(.callout.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(.thinMaterial))
                    }

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Trick.all) { t in
                                TrickRow(trick: t, onTap: { practice(t) })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("芸の練習")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func practice(_ trick: Trick) {
        let gain = store.practice(trick: trick)
        if gain > 0 {
            switch trick.id {
            case "sit":   practicePose = .sit
            case "down":  practicePose = .lie
            case "paw", "high5": practicePose = .beg
            case "spin":  practicePose = .jump
            case "wait":  practicePose = .stand
            default:      practicePose = .sit
            }
            lastResult = "\(trick.label) +\(Int(gain))%"
            audio.play(.ding)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                practicePose = .sit
            }
        } else {
            lastResult = "うまくいかなかった…"
            audio.play(.no)
        }
    }
}

private struct TrickRow: View {
    @EnvironmentObject var store: DogStore
    let trick: Trick
    let onTap: () -> Void

    var body: some View {
        let progress = store.dog.trickProgress[trick.id] ?? 0
        let unlocked = trick.isUnlocked(in: store.dog)
        Button(action: { if unlocked { onTap() } }) {
            HStack(spacing: 12) {
                Image(systemName: trick.icon)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .background(
                        Circle().fill(unlocked ? .purple : Color.gray.opacity(0.5))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trick.label).font(.headline)
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if progress >= 100 {
                            Text("マスター")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(.yellow))
                                .foregroundStyle(.black)
                        }
                        Spacer()
                        Text("\(Int(progress))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if unlocked {
                        ProgressView(value: progress / 100)
                            .tint(.purple)
                    } else {
                        Text(trick.lockReason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

// MARK: - トイレ訓練画面

struct ToiletView: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss
    @State private var resultText: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DogCanvas(pose: .sit, excited: false, size: 200)
                    .padding(.top)
                Text("トイレ訓練")
                    .font(.title2.bold())
                Text("成功するたびに少しずつ覚えます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    HStack {
                        Text("習熟度")
                        Spacer()
                        Text("\(Int(store.dog.toiletMastery))/100")
                            .monospacedDigit()
                    }
                    ProgressView(value: store.dog.toiletMastery / 100).tint(.cyan)
                }
                .padding(.horizontal, 30)

                Button {
                    store.toiletTrain()
                    if let ev = store.lastEvent {
                        resultText = ev.text
                        audio.play(ev.kind == .achievement ? .ding : .no)
                    }
                } label: {
                    Text("トイレに連れて行く")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(.cyan))
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .padding(.horizontal, 30)

                if let r = resultText {
                    Text(r).font(.callout)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
                        .padding(.horizontal, 30)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
