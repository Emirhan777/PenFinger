import SwiftUI
import UIKit
import LinkPresentation

enum PhotoShareOutcome: Equatable {
    case cancelled, failed, sent, saved, copied, printed, shared

    static func result(activity: UIActivity.ActivityType?, completed: Bool, error: Error?) -> Self {
        if error != nil { return .failed }
        guard completed else { return .cancelled }
        switch activity {
        case .saveToCameraRoll: return .saved
        case .copyToPasteboard: return .copied
        case .print: return .printed
        case .message, .mail, .airDrop: return .sent
        default:
            // Third-party extensions supply their own activity identifiers.
            return activity?.rawValue.lowercased().contains("whatsapp") == true ? .sent : .shared
        }
    }

    var confirmation: String? {
        switch self {
        case .sent: return "Photo sent"
        case .saved: return "Photo saved"
        case .copied: return "Photo copied"
        case .printed: return "Photo printed"
        case .shared: return "Photo shared"
        case .cancelled, .failed: return nil
        }
    }
}

final class PhotoShareItem: NSObject, UIActivityItemSource {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "PenFinger photo"
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}

final class PhotoInvitation: NSObject, UIActivityItemSource {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6757021735")!
    static let message = "Try the PenFinger app out and draw with your fingers!\n\(appStoreURL.absoluteString)"

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        Self.message
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // These actions operate on the photo itself, without promotional text.
        switch activityType {
        case .saveToCameraRoll, .copyToPasteboard, .print, .assignToContact: return nil
        default: return Self.message
        }
    }
}

struct PhotoShareButton: UIViewRepresentable {
    let image: UIImage
    let onStart: () -> Void
    let onCompletion: (PhotoShareOutcome) -> Void

    static func activityItems(for image: UIImage) -> [Any] {
        // Send the actual composite photo and keep the invitation/link together
        // as its accompanying text, so image sharing remains available.
        [PhotoShareItem(image: image), PhotoInvitation()]
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Share"
        configuration.image = UIImage(systemName: "square.and.arrow.up")
        configuration.imagePadding = 6
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "sharePhotoButton"
        button.addTarget(context.coordinator, action: #selector(Coordinator.share(_:)), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.parent = self
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        CGSize(width: uiView.intrinsicContentSize.width, height: max(44, uiView.intrinsicContentSize.height))
    }

    final class Coordinator: NSObject {
        var parent: PhotoShareButton

        init(parent: PhotoShareButton) { self.parent = parent }

        @objc func share(_ button: UIButton) {
            var responder: UIResponder? = button
            while responder != nil && !(responder is UIViewController) { responder = responder?.next }
            guard var presenter = responder as? UIViewController else { return }
            while let presented = presenter.presentedViewController { presenter = presented }
            guard presenter.view.window != nil else { return }

            parent.onStart()
            button.isEnabled = false
            let controller = UIActivityViewController(activityItems: PhotoShareButton.activityItems(for: parent.image),
                                                      applicationActivities: nil)
            controller.overrideUserInterfaceStyle = .dark
            // Anchor the native iPad popover to the button. On iPhone UIKit uses
            // its own share-sheet presentation, without an extra SwiftUI sheet.
            controller.popoverPresentationController?.sourceView = button
            controller.popoverPresentationController?.sourceRect = button.bounds
            controller.completionWithItemsHandler = { [weak self, weak button] activity, completed, _, error in
                let outcome = PhotoShareOutcome.result(activity: activity, completed: completed, error: error)
                Task { @MainActor in
                    button?.isEnabled = true
                    self?.parent.onCompletion(outcome)
                }
            }
            presenter.present(controller, animated: true)
        }
    }
}
