import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError, Equatable {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Allow PenFinger to add photos in Settings. You can still share this photo."
        case .saveFailed:
            "Try saving this photo with Share."
        }
    }
}

enum PhotoSaveStatus: Equatable {
    case saving
    case saved
    case failed(PhotoLibrarySaveError)
}

struct PhotoLibrarySaver {
    typealias Completion = (Result<Void, PhotoLibrarySaveError>) -> Void
    private let requestAccess: (@escaping (PHAuthorizationStatus) -> Void) -> Void
    private let writeImage: (UIImage, @escaping (Bool) -> Void) -> Void

    init(requestAccess: @escaping (@escaping (PHAuthorizationStatus) -> Void) -> Void = { completion in
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: completion)
        } else {
            completion(status)
        }
    }, writeImage: @escaping (UIImage, @escaping (Bool) -> Void) -> Void = { image, completion in
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, _ in
            completion(success)
        }
    }) {
        self.requestAccess = requestAccess
        self.writeImage = writeImage
    }

    func save(_ image: UIImage, completion: @escaping Completion) {
        requestAccess { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(.accessDenied))
                return
            }
            writeImage(image) { success in
                completion(success ? .success(()) : .failure(.saveFailed))
            }
        }
    }
}
