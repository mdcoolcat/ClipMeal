import SwiftUI
import SwiftData

struct AddRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var viewModel: AddRecipeViewModel?
    var onRecipeSaved: ((Recipe) -> Void)?

    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        setupViewModel()
                    }
            }
        }
    }

    @ViewBuilder
    private func contentView(viewModel: AddRecipeViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Add Recipe from URL")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Paste a link from YouTube, TikTok, Instagram, or a recipe website")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)

            // Input Section
            VStack(alignment: .leading, spacing: 12) {
                TextField("Paste recipe URL here", text: $viewModel.urlText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(viewModel.status.isLoading)


            }
            .padding(.horizontal)

            // Action Button
            Button(action: {
                // Dismiss keyboard first
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task {
                    await viewModel.extractRecipe()
                }
            }) {
                Text("Extract Recipe")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canSubmit ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal)

            // Status Display
            LoadingStateView(status: viewModel.status) {
                viewModel.reset()
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            viewModel.clearInput()
        }
        .navigationTitle("Add Recipe")
        .sheet(isPresented: Binding(
            get: { viewModel.showPaywall },
            set: { viewModel.showPaywall = $0 }
        )) {
            PaywallView()
                .environment(subscriptionManager)
        }
    }

    private func setupViewModel() {
        let repository = RecipeRepository(modelContext: modelContext)
        let apiClient = APIClient()
        viewModel = AddRecipeViewModel(apiClient: apiClient, repository: repository, subscriptionManager: subscriptionManager, onRecipeSaved: onRecipeSaved)
    }
}

#Preview {
    AddRecipeView()
        .modelContainer(PersistenceController.preview.modelContainer)
}
