import UIKit
import SwiftUI
import SwiftData

class ShareViewController: UIViewController {
    private var hostingController: UIViewController?
    private let persistenceController = PersistenceController.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Extract URL asynchronously
        Task {
            if let url = await extractURL() {
                await MainActor.run {
                    setupSwiftUIView(url: url)
                }
            } else {
                await MainActor.run {
                    showError("No valid URL found")
                }
            }
        }
    }

    private func extractURL() async -> String? {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return nil
        }

        // Handle URL type
        if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            do {
                let item = try await itemProvider.loadItem(forTypeIdentifier: "public.url")
                if let url = item as? URL {
                    return url.absoluteString
                }
            } catch {
                print("Error loading URL: \(error)")
            }
        }

        // Handle plain text (URLs shared as text)
        if itemProvider.hasItemConformingToTypeIdentifier("public.text") {
            do {
                let item = try await itemProvider.loadItem(forTypeIdentifier: "public.text")
                if let text = item as? String,
                   let url = URL(string: text),
                   url.scheme != nil {
                    return text
                }
            } catch {
                print("Error loading text: \(error)")
            }
        }

        return nil
    }

    private func setupSwiftUIView(url: String) {
        let modelContext = persistenceController.modelContainer.mainContext
        let repository = RecipeRepository(modelContext: modelContext)
        let viewModel = ShareViewModel(
            url: url,
            apiClient: APIClient(),
            repository: repository,
            onComplete: { [weak self] success in
                self?.handleCompletion(success: success)
            }
        )

        let shareView = ShareView(viewModel: viewModel)
            .modelContainer(persistenceController.modelContainer)

        let hosting = UIHostingController(rootView: shareView)
        hostingController = hosting

        // Embed SwiftUI view
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
    }

    private func handleCompletion(success: Bool) {
        if success {
            // Open main app after successful extraction
            if let appURL = URL(string: "clipmeal://recipes") {
                extensionContext?.open(appURL, completionHandler: { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                })
            } else {
                extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: "RecipeShareExtension", code: -1))
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "RecipeShareExtension", code: -1))
        })
        present(alert, animated: true)
    }
}
