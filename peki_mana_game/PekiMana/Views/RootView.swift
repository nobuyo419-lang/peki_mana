// RootView.swift — 画面ルーター
import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DogStore
    @State private var sheet: GameSheet? = nil
    @State private var showEnding = false

    var body: some View {
        ZStack {
            HomeView(sheet: $sheet)
                .onAppear {
                    if !store.dog.seenIntro {
                        sheet = .nameInput
                    }
                    if let _ = store.availableEnding {
                        showEnding = true
                    }
                }
                .onChange(of: store.dog.totalActions) { _, _ in
                    if !showEnding, let _ = store.availableEnding {
                        showEnding = true
                    }
                }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .nameInput:
                NameInputView()
                    .interactiveDismissDisabled(!store.dog.seenIntro)
            case .training:
                TrainingView()
            case .ball:
                MiniGameBallView()
            case .brush:
                MiniGameBrushView()
            case .stats:
                StatsDetailView()
            case .toilet:
                ToiletView()
            }
        }
        .sheet(isPresented: $showEnding) {
            if let ending = store.availableEnding {
                EndingView(ending: ending)
            }
        }
    }
}

enum GameSheet: Identifiable {
    case nameInput, training, ball, brush, stats, toilet
    var id: String { String(describing: self) }
}
