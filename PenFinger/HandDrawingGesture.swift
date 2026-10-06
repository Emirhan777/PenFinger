import CoreGraphics
import Vision

struct HandLandmark {
    let location: CGPoint
    let confidence: Float
}

/// Follows a tracked index fingertip unless a clenched fist can be detected.
enum HandDrawingGesture {
    typealias Joint = VNHumanHandPoseObservation.JointName

    static func drawingTip(in landmarks: [Joint: HandLandmark], imageSize: CGSize) -> CGPoint? {
        guard imageSize.width.isFinite, imageSize.height.isFinite,
              imageSize.width > 0, imageSize.height > 0,
              let indexTip = landmarks[.indexTip], indexTip.confidence > 0.6,
              point(.indexTip, in: landmarks, imageSize: imageSize) != nil else { return nil }

        // A cropped palm must not prevent a visible fingertip from drawing.
        guard let wrist = point(.wrist, in: landmarks, imageSize: imageSize) else {
            return indexTip.location
        }

        let fingers: [(Joint, Joint, Joint)] = [
            (.indexMCP, .indexPIP, .indexTip),
            (.middleMCP, .middlePIP, .middleTip),
            (.ringMCP, .ringPIP, .ringTip),
            (.littleMCP, .littlePIP, .littleTip)
        ]
        for (base, joint, tip) in fingers {
            guard let finger = finger(base, joint, tip, in: landmarks, imageSize: imageSize),
                  finger.isCurled(from: wrist) else {
                // Continue if a finger is open or there is too little visible
                // hand to confirm a fist.
                return indexTip.location
            }
        }
        // The thumb can rest across a fist or stick out without opening the hand.
        // Pause only when all four fingers can be confirmed curled.
        return nil
    }

    private static func point(_ joint: Joint, in landmarks: [Joint: HandLandmark],
                              imageSize: CGSize) -> CGPoint? {
        guard let point = landmarks[joint], point.confidence >= 0.3,
              point.location.x.isFinite, point.location.y.isFinite,
              (0...1).contains(point.location.x), (0...1).contains(point.location.y)
        else { return nil }
        // Angles need image coordinates: normalized x/y have different scales
        // in a rectangular camera image. Distances and bends then work at any roll.
        return CGPoint(x: point.location.x * imageSize.width,
                       y: point.location.y * imageSize.height)
    }

    private static func finger(_ base: Joint, _ joint: Joint, _ tip: Joint,
                               in landmarks: [Joint: HandLandmark], imageSize: CGSize) -> Finger? {
        guard let base = point(base, in: landmarks, imageSize: imageSize),
              let joint = point(joint, in: landmarks, imageSize: imageSize),
              let tip = point(tip, in: landmarks, imageSize: imageSize)
        else { return nil }
        let proximal = CGVector(dx: base.x - joint.x, dy: base.y - joint.y)
        let distal = CGVector(dx: tip.x - joint.x, dy: tip.y - joint.y)
        let lengths = hypot(proximal.dx, proximal.dy) * hypot(distal.dx, distal.dy)
        guard lengths > 0.0001 else { return nil }
        let bend = (proximal.dx * distal.dx + proximal.dy * distal.dy) / lengths
        return Finger(base: base, tip: tip, bend: bend)
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private struct Finger {
        let base: CGPoint
        let tip: CGPoint
        let bend: CGFloat

        func isCurled(from wrist: CGPoint) -> Bool {
            // A bend alone also occurs in a partly open hand. A fist's fingertips
            // curl back toward the palm, near or below their base knuckles.
            bend > -0.3 && distance(tip, wrist) <= distance(base, wrist) * 1.2
        }
    }
}
