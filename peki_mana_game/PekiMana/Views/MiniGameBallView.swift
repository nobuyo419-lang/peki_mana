// MiniGameBallView.swift — ボール遊びミニゲーム
import SwiftUI
import Combine

struct MiniGameBallView: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss

    @State private var ballX: CGFloat = 0
    @State private var ballY: CGFloat = 0
    @State private var dragStart: CGPoint? = nil
    @State private var ballFlying = false
    @State private var dogChasing = false
    @State private var fetchCount = 0
    @State private var dogPose: DogPose = .sit
    @State private var startTime = Date()
    private let duration: TimeInterval = 30

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    BackgroundCanvas(season: Season.current,
                                     timeOfDay: TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date())))

                    VStack {
                        HStack {
                            Text("キャッチ!")
                                .font(.headline)
                            Spacer()
                            Text("\(fetchCount) 回")
                                .font(.title3.bold())
                            Spacer()
                            Text("残り \(Int(max(0, duration - Date().timeIntervalSince(startTime))))秒")
                                .font(.caption.monospacedDigit())
                        }
                        .padding(12)
                        .background(.thinMaterial, in: Capsule())
                        .padding()
                        Spacer()
                    }

                    // 犬
                    DogCanvas(pose: dogPose, excited: dogChasing, size: 200)
                        .position(x: geo.size.width / 2,
                                  y: geo.size.height * 0.78)

                    // ボール
                    Circle()
                        .fill(.red)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Path { p in
                                p.move(to: CGPoint(x: 18, y: 0))
                                p.addLine(to: CGPoint(x: 18, y: 36))
                            }.stroke(.white.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(radius: 2)
                        .position(x: ballX == 0 ? geo.size.width / 2 : ballX,
                                  y: ballY == 0 ? geo.size.height * 0.85 : ballY)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    if !ballFlying {
                                        if dragStart == nil { dragStart = v.startLocation }
                                        ballX = v.location.x
                                        ballY = v.location.y
                                    }
                                }
                                .onEnded { v in
                                    guard !ballFlying, let _ = dragStart else { return }
                                    throwBall(to: v.location, in: geo.size)
                                }
                        )
                }
                .onAppear {
                    ballX = geo.size.width / 2
                    ballY = geo.size.height * 0.85
                    startTime = Date()
                }
            }
            .navigationTitle("ボール遊び")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("終了") { finish(); dismiss() }
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if Date().timeIntervalSince(startTime) >= duration {
                    finish(); dismiss()
                }
            }
        }
    }

    private func throwBall(to target: CGPoint, in canvas: CGSize) {
        ballFlying = true
        dogChasing = true
        dogPose = .stand
        audio.play(.bark)

        // 追いかけ + 戻ってくる
        withAnimation(.easeOut(duration: 0.7)) {
            ballX = target.x
            ballY = max(target.y, canvas.height * 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            // dog reaches ball
            withAnimation(.easeIn(duration: 0.5)) {
                ballX = canvas.width / 2
                ballY = canvas.height * 0.78
            }
            audio.play(.happy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeIn(duration: 0.4)) {
                ballX = canvas.width / 2
                ballY = canvas.height * 0.85
            }
            dogChasing = false
            dogPose = .sit
            ballFlying = false
            dragStart = nil
            fetchCount += 1
        }
    }

    private func finish() {
        if fetchCount > 0 {
            store.dog.affection = clamp(store.dog.affection + Double(fetchCount) * 0.7 * store.dog.welcomeBoost)
            store.dog.energy = clamp(store.dog.energy - Double(fetchCount) * 1.2)
            store.dog.totalActions += 1
            store.event("ボール遊び \(fetchCount) 回キャッチ。仲良し度アップ。", kind: .affection)
            store.persist()
        }
    }
}
