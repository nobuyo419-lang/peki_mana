// HomeView.swift — メイン画面
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager
    @Binding var sheet: GameSheet?

    @State private var pose: DogPose = .sit
    @State private var poseExcited: Bool = false
    @State private var poseResetWork: DispatchWorkItem?

    private var timeOfDay: TimeOfDay {
        TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date()))
    }

    var body: some View {
        ZStack(alignment: .top) {
            BackgroundCanvas(season: Season.current, timeOfDay: timeOfDay)

            VStack(spacing: 0) {
                StatsBar()
                    .padding(.top, 8)
                    .padding(.horizontal)
                Spacer()
            }

            // Dog
            VStack {
                Spacer()
                DogCanvas(pose: store.dog.isAsleep ? .sleep : pose,
                          excited: poseExcited,
                          size: 320)
                    .onTapGesture {
                        store.pet()
                        triggerPose(.beg, excited: true, dur: 1.4)
                        audio.play(.bark)
                    }
                Spacer().frame(height: 110)
            }

            // Event log floating banner
            VStack {
                Spacer()
                if let ev = store.lastEvent {
                    EventBanner(event: ev)
                        .padding(.bottom, 110)
                        .id(ev.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ActionBar(sheet: $sheet, onAction: handleAction)
                    .padding(.bottom, 18)
                    .padding(.horizontal, 12)
            }
            .animation(.easeOut(duration: 0.25), value: store.lastEvent?.id)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: store.dog.isAsleep) { _, asleep in
            if asleep { audio.play(.snore) }
        }
    }

    private func handleAction(_ action: HomeAction) {
        switch action {
        case .pet:
            store.pet()
            triggerPose(.beg, excited: true, dur: 1.2)
            audio.play(.happy)
        case .feed:
            store.feedMeal()
            triggerPose(.lie, excited: false, dur: 1.4)
            audio.play(.treat)
        case .treat:
            store.giveTreat()
            triggerPose(.jump, excited: true, dur: 1.4)
            audio.play(.treat)
        case .walk:
            store.walk()
            triggerPose(.stand, excited: true, dur: 1.6)
            audio.play(.happy)
        case .bath:
            store.bath()
            triggerPose(.stand, excited: false, dur: 1.4)
            audio.play(.splash)
        case .sleep:
            store.sleep()
        case .training:
            sheet = .training
        case .ball:
            sheet = .ball
        case .brush:
            sheet = .brush
        case .toilet:
            sheet = .toilet
        case .stats:
            sheet = .stats
        }
    }

    private func triggerPose(_ p: DogPose, excited: Bool, dur: Double) {
        poseResetWork?.cancel()
        pose = p
        poseExcited = excited
        let w = DispatchWorkItem {
            pose = .sit
            poseExcited = false
        }
        poseResetWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + dur, execute: w)
    }
}

// MARK: - イベントバナー

struct EventBanner: View {
    let event: GameEvent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white)
            Text(event.text)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(color.opacity(0.92))
        )
        .padding(.horizontal, 24)
    }

    private var color: Color {
        switch event.kind {
        case .info: return .gray
        case .care: return .teal
        case .affection: return .pink
        case .achievement: return .orange
        }
    }

    private var icon: String {
        switch event.kind {
        case .info: return "info.circle.fill"
        case .care: return "heart.text.square.fill"
        case .affection: return "heart.fill"
        case .achievement: return "star.fill"
        }
    }
}

// MARK: - アクション

enum HomeAction {
    case pet, feed, treat, walk, bath, sleep, training, ball, brush, toilet, stats
}

struct ActionBar: View {
    @Binding var sheet: GameSheet?
    let onAction: (HomeAction) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton("撫でる", systemImage: "hand.point.up.left.fill", color: .pink) { onAction(.pet) }
                actionButton("ごはん", systemImage: "fork.knife", color: .orange) { onAction(.feed) }
                actionButton("おやつ", systemImage: "gift.fill", color: .yellow) { onAction(.treat) }
                actionButton("散歩", systemImage: "figure.walk", color: .green) { onAction(.walk) }
            }
            HStack(spacing: 10) {
                actionButton("お風呂", systemImage: "shower.fill", color: .blue) { onAction(.bath) }
                actionButton("ねんね", systemImage: "moon.zzz.fill", color: .indigo) { onAction(.sleep) }
                actionButton("トイレ", systemImage: "drop.fill", color: .cyan) { onAction(.toilet) }
                actionButton("ブラシ", systemImage: "paintbrush.fill", color: .brown) { onAction(.brush) }
            }
            HStack(spacing: 10) {
                actionButton("芸の練習", systemImage: "sparkles", color: .purple) { onAction(.training) }
                actionButton("ボール", systemImage: "circle.fill", color: .red) { onAction(.ball) }
                actionButton("ステータス", systemImage: "chart.bar.fill", color: .gray) { onAction(.stats) }
            }
        }
    }

    private func actionButton(_ label: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.gradient)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
