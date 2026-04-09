import SwiftUI

struct ShareView: View {
    @Bindable var viewModel: ShareViewModel
    @State private var showProgressMessage = false

    private var appIcon: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIconImage", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let icon = UIImage(data: data) {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                appIcon
                Text(AppConstants.appDisplayName)
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    viewModel.cancel()
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.systemBackground))

            Spacer()

            // Status Display
            statusView

            Spacer()
        }
        .task {
            await viewModel.startExtraction()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()

        case .validating:
            VStack(spacing: 12) {
                WhiskLoadingView(size: 40)
                Text("Validating URL...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Already Saved")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This recipe is already in your list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("OK") {
                    viewModel.cancel()
                }
                .padding(.top, 8)
            }
            .padding()

        case .success(let recipe):
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Recipe Saved!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(recipe.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                }

                Text("Closing...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                VStack(spacing: 8) {
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Close") {
                    viewModel.cancel()
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}
