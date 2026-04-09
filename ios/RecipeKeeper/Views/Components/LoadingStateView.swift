import SwiftUI

struct LoadingStateView: View {
    let status: ExtractionStatus
    let onDismiss: () -> Void
    @State private var showProgressMessage = false

    var body: some View {
        switch status {
        case .idle:
            EmptyView()

        case .validating:
            VStack(spacing: 12) {
                WhiskLoadingView(size: 40)
                Text("Validating URL...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .extracting:
            VStack(spacing: 12) {
                WhiskLoadingView(size: 40)
                Text("Extracting recipe...")
                    .font(.subheadline)
                if showProgressMessage {
                    Text(AppConstants.progressMessageText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .onAppear {
                showProgressMessage = false
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(AppConstants.progressMessageDelaySec * 1_000_000_000))
                    showProgressMessage = true
                }
            }
            .onDisappear {
                showProgressMessage = false
            }

        case .alreadySaved:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                Text("Already Saved")
                    .font(.headline)

                Text("This recipe is already in your list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("OK") {
                    onDismiss()
                }
                .padding(.top, 8)
            }
            .padding()

        case .success(let recipe):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)

                Text("Recipe Saved!")
                    .font(.headline)

                Text(recipe.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button("Add Another") {
                    onDismiss()
                }
                .padding(.top, 8)
            }
            .padding()

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)

                Text("Error")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                Button("Try Again") {
                    onDismiss()
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}
