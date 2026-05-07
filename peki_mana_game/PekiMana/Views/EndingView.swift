// EndingView.swift — エンディング画面
import SwiftUI

struct EndingView: View {
    @EnvironmentObject var store: DogStore
    @Environment(\.dismiss) private var dismiss
    let ending: Ending

    var body: some View {
        ZStack {
            LinearGradient(colors: [.yellow.opacity(0.3), .pink.opacity(0.3), .purple.opacity(0.2)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("ENDING")
                    .font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.7)))
                    .foregroundStyle(.white)

                Text(ending.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                DogCanvas(pose: .beg, excited: true, size: 240)

                Text(ending.body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("\(store.dog.dayCount)日間をマナと過ごしました。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("続ける") {
                        store.claimEnding(ending)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("最初から") {
                        store.resetAll()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
            .padding()
        }
        .interactiveDismissDisabled(true)
    }
}
