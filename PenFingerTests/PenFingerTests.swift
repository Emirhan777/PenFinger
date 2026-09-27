import Testing
import UIKit
@testable import PenFinger

@MainActor
struct PhotoSharingTests {
    @Test func shareIncludesTheCompositePhotoAndDownloadInvitation() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let items = PhotoShareButton.activityItems(for: photo)
        #expect(items.count == 2)
        let photoItem = try #require(items.first as? PhotoShareItem)
        let invitation = try #require(items.last as? PhotoInvitation)
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let whatsapp = UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension")
        for activity in [whatsapp, .message, .mail] {
            #expect((photoItem.activityViewController(controller, itemForActivityType: activity) as? UIImage) === photo)
            let text = invitation.activityViewController(controller, itemForActivityType: activity) as? String
            #expect(text == "Try the PenFinger app out and draw with your fingers!\nhttps://apps.apple.com/app/id6757021735")
        }
        for activity in [UIActivity.ActivityType.saveToCameraRoll, .copyToPasteboard, .print] {
            #expect(invitation.activityViewController(controller, itemForActivityType: activity) == nil)
        }
    }

    @Test func cancelledOrFailedSharesNeverConfirmSuccess() {
        let whatsapp = UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension")
        let cancelled = PhotoShareOutcome.result(activity: whatsapp, completed: false, error: nil)
        #expect(cancelled == .cancelled)
        #expect(cancelled.confirmation == nil)
        #expect(PhotoShareOutcome.result(activity: nil, completed: false, error: nil) == .cancelled)
        for completed in [false, true] {
            let failure = PhotoShareOutcome.result(activity: whatsapp, completed: completed,
                                                   error: NSError(domain: "ShareTest", code: 1))
            #expect(failure == .failed)
            #expect(failure.confirmation == nil)
        }
    }

    @Test func successfulShareConfirmationDescribesTheAction() {
        let whatsapp = UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension")
        for activity in [whatsapp, .message, .mail, .airDrop] {
            #expect(PhotoShareOutcome.result(activity: activity, completed: true, error: nil).confirmation == "Photo sent")
        }
        #expect(PhotoShareOutcome.result(activity: .saveToCameraRoll, completed: true, error: nil).confirmation == "Photo saved")
        #expect(PhotoShareOutcome.result(activity: .copyToPasteboard, completed: true, error: nil).confirmation == "Photo copied")
        #expect(PhotoShareOutcome.result(activity: .print, completed: true, error: nil).confirmation == "Photo printed")
        #expect(PhotoShareOutcome.result(activity: UIActivity.ActivityType("another.extension"), completed: true,
                                        error: nil).confirmation == "Photo shared")
    }
}

@MainActor
struct PhotoRendererTests {
    @Test func portraitPhotoMatchesVisibleCropAndDrawing() throws {
        let photo = makeImage(size: CGSize(width: 400, height: 300)) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            UIColor.green.setFill()
            context.fill(CGRect(x: 125, y: 0, width: 150, height: 300))
        }
        let result = try #require(PhotoRenderer.render(
            photo: photo, points: [CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.75, y: 0.5)],
            viewportSize: CGSize(width: 100, height: 200)))

        #expect(result.size == CGSize(width: 150, height: 300))
        #expect(isGreen(pixel(result, x: 1, y: 100)))
        #expect(isGreen(pixel(result, x: 148, y: 100)))
        #expect(isBlack(pixel(result, x: 75, y: 150)))
        #expect(isBlack(pixel(result, x: 75, y: 148)))
        #expect(isGreen(pixel(result, x: 75, y: 145)))
        #expect(isGreen(pixel(result, x: 20, y: 150)))
    }

    @Test func landscapePhotoCropsVertically() throws {
        let photo = makeImage(size: CGSize(width: 400, height: 300)) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 50, width: 400, height: 200))
        }
        let result = try #require(PhotoRenderer.render(photo: photo, points: [],
                                                       viewportSize: CGSize(width: 200, height: 100)))
        #expect(result.size == CGSize(width: 400, height: 200))
        #expect(isGreen(pixel(result, x: 100, y: 1)))
        #expect(isGreen(pixel(result, x: 100, y: 198)))
    }

    @Test func cameraOrientationIsAppliedToTheExport() throws {
        let raw = makeImage(size: CGSize(width: 200, height: 100)) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.green.setFill()
            context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        }
        let oriented = UIImage(cgImage: try #require(raw.cgImage), scale: 1, orientation: .right)
        let result = try #require(PhotoRenderer.render(photo: oriented, points: [],
                                                       viewportSize: CGSize(width: 100, height: 200)))
        #expect(result.size == CGSize(width: 100, height: 200))
        #expect(result.imageOrientation == .up)
        let top = pixel(result, x: 50, y: 25)
        #expect(top[0] > 240 && top[1] < 15)
        #expect(isGreen(pixel(result, x: 50, y: 175)))
    }

    @Test func emptyOrSinglePointDrawingStillProducesAPhoto() throws {
        let photo = makeImage(size: CGSize(width: 100, height: 100)) { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        for points in [[], [CGPoint(x: 0.5, y: 0.5)]] {
            let result = try #require(PhotoRenderer.render(photo: photo, points: points, viewportSize: photo.size))
            #expect(isGreen(pixel(result, x: 50, y: 50)))
        }
        #expect(PhotoRenderer.render(photo: photo, points: [], viewportSize: .zero) == nil)
    }

    private func makeImage(size: CGSize, draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: draw)
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) -> [UInt8] {
        let cropped = image.cgImage!.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))!
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                                    bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes
    }

    private func isGreen(_ pixel: [UInt8]) -> Bool { pixel[0] < 15 && pixel[1] > 240 && pixel[2] < 15 }
    private func isBlack(_ pixel: [UInt8]) -> Bool { pixel[0] < 15 && pixel[1] < 15 && pixel[2] < 15 }
}
