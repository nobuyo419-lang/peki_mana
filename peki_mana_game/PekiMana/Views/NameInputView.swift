// NameInputView.swift — 初回起動時の名前入力
import SwiftUI

struct NameInputView: View {
    @EnvironmentObject var store: DogStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "マナ"

    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink.opacity(0.25), .yellow.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("はじめまして")
                    .font(.largeTitle.bold())

                DogCanvas(pose: .sit, excited: false, size: 220)

                Text("この子に名前をつけてあげてください。")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                TextField("名前", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .padding(.horizontal, 50)

                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    store.dog.name = trimmed.isEmpty ? "マナ" : trimmed
                    store.dog.seenIntro = true
                    store.persist()
                    dismiss()
                } label: {
                    Text("一緒に暮らしはじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(.pink))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 20)
            }
        }
    }
}
