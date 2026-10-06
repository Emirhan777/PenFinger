import UIKit

/// Composes only the photo and ink, using the same crop and line width as the live view.
enum PhotoRenderer {
    static let lineWidth: CGFloat = 4

    static func render(photo: UIImage, strokes: [DrawingStroke], viewportSize: CGSize) -> UIImage? {
        guard viewportSize.width.isFinite, viewportSize.height.isFinite,
              viewportSize.width > 0, viewportSize.height > 0,
              photo.size.width > 0, photo.size.height > 0 else { return nil }

        // Retain the photo's resolution within the visible crop rather than enlarging
        // a screenshot. UIImage.draw also applies the camera's EXIF orientation.
        let scale = min(photo.size.width * photo.scale / viewportSize.width,
                        photo.size.height * photo.scale / viewportSize.height)
        let outputSize = CGSize(width: viewportSize.width * scale,
                                height: viewportSize.height * scale)
        let imageScale = max(outputSize.width / photo.size.width,
                             outputSize.height / photo.size.height)
        let imageRect = CGRect(
            x: (outputSize.width - photo.size.width * imageScale) / 2,
            y: (outputSize.height - photo.size.height * imageScale) / 2,
            width: photo.size.width * imageScale,
            height: photo.size.height * imageScale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            photo.draw(in: imageRect)
            for stroke in strokes {
                guard stroke.points.count > 1, let first = stroke.points.first else { continue }
                let path = UIBezierPath()
                path.move(to: CGPoint(x: first.x * outputSize.width, y: first.y * outputSize.height))
                for point in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * outputSize.width, y: point.y * outputSize.height))
                }
                path.lineWidth = lineWidth * scale
                stroke.color.uiColor.setStroke()
                path.stroke()
            }
        }
    }
}
