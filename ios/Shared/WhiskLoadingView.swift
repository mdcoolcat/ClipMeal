import SwiftUI

/// Custom loading animation using an SF Symbol
struct WhiskLoadingView: View {
    @State private var rotation: Double = -20
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "fork.knife")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(.orange)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.3)
                    .repeatForever(autoreverses: true)
                ) {
                    rotation = 20
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        WhiskLoadingView(size: 32)
        WhiskLoadingView(size: 48)
        WhiskLoadingView(size: 64)
    }
}
