import Testing
import Photos
import UIKit
@testable import PenFinger

@MainActor
struct PhotoLibrarySaverTests {
    @Test func waitsForPermissionAndWriteCompletionBeforeReportingSuccess() throws {
        let image = UIImage()
        var authorize: ((PHAuthorizationStatus) -> Void)?
        var finishWrite: ((Bool) -> Void)?
        var writtenImages: [UIImage] = []
        var results: [Result<Void, PhotoLibrarySaveError>] = []
        let saver = PhotoLibrarySaver(requestAccess: { authorize = $0 }, writeImage: { image, completion in
            writtenImages.append(image)
            finishWrite = completion
        })

        saver.save(image) { results.append($0) }
        #expect(writtenImages.isEmpty)
        #expect(results.isEmpty)
        let grantAccess = try #require(authorize)
        grantAccess(.authorized)
        #expect(writtenImages.count == 1)
        #expect(writtenImages.first === image)
        #expect(results.isEmpty)

        let completeWrite = try #require(finishWrite)
        completeWrite(true)
        #expect(results.count == 1)
        try #require(results.first).get()
    }

    @Test func deniedOrUnresolvedPermissionNeverWritesAPhoto() {
        for status: PHAuthorizationStatus in [.denied, .restricted, .notDetermined] {
            var writes = 0
            var failure: PhotoLibrarySaveError?
            let saver = PhotoLibrarySaver(requestAccess: { $0(status) }, writeImage: { _, _ in
                writes += 1
            })
            saver.save(UIImage()) {
                if case .failure(let error) = $0 { failure = error }
            }
            #expect(writes == 0)
            #expect(failure == .accessDenied)
        }
    }

    @Test func unsuccessfulWriteReportsFailure() {
        var writes = 0
        var failure: PhotoLibrarySaveError?
        let saver = PhotoLibrarySaver(requestAccess: { $0(.authorized) }, writeImage: { _, completion in
            writes += 1
            completion(false)
        })
        saver.save(UIImage()) {
            if case .failure(let error) = $0 { failure = error }
        }
        #expect(writes == 1)
        #expect(failure == .saveFailed)
    }
}
