// MiniGameBrushView.swift — ブラッシングミニゲーム
import SwiftUI

struct MiniGameBrushView: View {
    @EnvironmentObject var store: DogStore
    @EnvironmentObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss

    @State private var strokes: Int = 0
    @State private var lastDragPoint: CGPoint? = nil
    @State private var totalDistance: CGFloat = 0
    @State private var sparkles: [Sparkle] = []

    struct Sparkle: Identifiable {
        let id = UUID()
        var pos: CGPoint
        var birth = Date()
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [.pink.opacity(0.2), .purple.opacity(0.15)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    VStack {
                        Text("マナを優しく撫でるようにスワイプ")
                            .font(.headline)
                            .padding(.top, 12)
                        Text("ストローク: \(strokes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    DogCanvas(pose: .lie, excited: strokes > 6, size: 280)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { v in
                                    if let last = lastDragPoint {
                                        let d = hypot(v.location.x - last.x, v.location.y - last.y)
                                        totalDistance += d
                                        if totalDistance > 50 {
                                            totalDistance = 0
                                            strokes += 1
                                            audio.play(.happy)
                                            sparkles.append(Sparkle(pos: v.location))
                                            sparkles = sparkles.filter { Date().timeIntervalSince($0.birth) < 0.8 }
                                        }
                                    }
                                    lastDragPoint = v.location
                                }
                                .onEnded { _ in lastDragPoint = nil }
                        )

                    ForEach(sparkles) { s in
                        let age = Date().timeIntervalSince(s.birth)
                        Image(systemName: "sparkle")
                            .foregroundStyle(.pink)
                            .opacity(1 - age / 0.8)
                            .scaleEffect(1 + CGFloat(age) * 1.5)
                            .position(s.pos)
                            .allowsHitTesting(false)
                    }
                }
            }
            .navigationTitle("ブラッシング")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        store.brush(strokes: strokes)
                        dismiss()
                    }
                }
            }
        }
    }
}
