import Testing
import CoreGraphics
import Vision
@testable import PenFinger

@MainActor
struct HandDrawingGestureTests {
    private typealias Joint = VNHumanHandPoseObservation.JointName
    private let imageSize = CGSize(width: 1080, height: 1920)

    @Test func pointingOpenAndPartlyOpenHandsProvideADrawingTip() {
        var middleOnly = fistHand()
        extend((.middleMCP, .middlePIP, .middleTip), in: &middleOnly)
        for hand in [pointingHand(), openHand(), partlyOpenHand(), middleOnly] {
            #expect(HandDrawingGesture.drawingTip(in: hand, imageSize: imageSize) == hand[.indexTip]?.location)
        }

        var occludedFingers = pointingHand()
        for joint: Joint in [.middlePIP, .ringTip, .littleTip, .thumbIP, .thumbTip] {
            occludedFingers[joint] = nil
        }
        #expect(HandDrawingGesture.drawingTip(in: occludedFingers, imageSize: imageSize) == occludedFingers[.indexTip]?.location)
    }

    @Test func clenchedFistPausesWithTheThumbTuckedOrExtended() {
        #expect(HandDrawingGesture.drawingTip(in: fistHand(), imageSize: imageSize) == nil)
        var extendedThumb = fistHand()
        extendedThumb[.thumbMP] = landmark(0.35, 0.30)
        extendedThumb[.thumbIP] = landmark(0.28, 0.39)
        extendedThumb[.thumbTip] = landmark(0.21, 0.48)
        #expect(HandDrawingGesture.drawingTip(in: extendedThumb, imageSize: imageSize) == nil)
    }

    @Test func detectionWorksForEitherHandAtDifferentRotationsAndSizes() {
        for size in [imageSize, CGSize(width: 1920, height: 1080)] {
            for angle in [CGFloat(0), .pi / 4, .pi / 2, .pi, .pi * 1.5] {
                for mirror in [false, true] {
                    for scale in [CGFloat(0.5), 1] {
                        func transform(_ hand: [Joint: HandLandmark]) -> [Joint: HandLandmark] {
                            hand.mapValues { point in
                                let x = (point.location.x - 0.5) * 600 * scale * (mirror ? -1 : 1)
                                let y = (point.location.y - 0.5) * 600 * scale
                                return HandLandmark(location: CGPoint(
                                    x: 0.5 + (x * cos(angle) - y * sin(angle)) / size.width,
                                    y: 0.5 + (x * sin(angle) + y * cos(angle)) / size.height),
                                    confidence: point.confidence)
                            }
                        }
                        for hand in [pointingHand(), openHand(), partlyOpenHand()] {
                            let transformed = transform(hand)
                            #expect(HandDrawingGesture.drawingTip(in: transformed, imageSize: size) == transformed[.indexTip]?.location)
                        }
                        #expect(HandDrawingGesture.drawingTip(in: transform(fistHand()), imageSize: size) == nil)
                    }
                }
            }
        }
    }

    @Test func unavailableFistLandmarksDoNotBlockATrackedFingertip() {
        let indexTip = openHand()[.indexTip]!
        #expect(HandDrawingGesture.drawingTip(in: [.indexTip: indexTip], imageSize: imageSize) == indexTip.location)
        for joint: Joint in [.wrist, .indexMCP, .indexPIP,
                             .middleMCP, .middlePIP, .middleTip,
                             .ringMCP, .ringPIP, .ringTip,
                             .littleMCP, .littlePIP, .littleTip] {
            var missing = fistHand()
            missing[joint] = nil
            #expect(HandDrawingGesture.drawingTip(in: missing, imageSize: imageSize) == missing[.indexTip]?.location)

            var uncertain = fistHand()
            uncertain[joint] = HandLandmark(location: uncertain[joint]!.location, confidence: 0.2)
            #expect(HandDrawingGesture.drawingTip(in: uncertain, imageSize: imageSize) == uncertain[.indexTip]?.location)

            var outsideFrame = fistHand()
            outsideFrame[joint] = landmark(0.4, -0.1)
            #expect(HandDrawingGesture.drawingTip(in: outsideFrame, imageSize: imageSize) == outsideFrame[.indexTip]?.location)
        }
        var degenerate = fistHand()
        degenerate[.indexPIP] = degenerate[.indexMCP]
        #expect(HandDrawingGesture.drawingTip(in: degenerate, imageSize: imageSize) == degenerate[.indexTip]?.location)
    }

    @Test func croppedLowerHandKeepsTheCurrentStrokeGoing() {
        var drawing = Drawing()
        var expectedPoints: [CGPoint] = []
        for offset: CGFloat in [0, -0.2, -0.45, -0.6, 0] {
            let hand = openHand().mapValues {
                HandLandmark(location: CGPoint(x: $0.location.x, y: $0.location.y + offset),
                             confidence: $0.confidence)
            }
            expectedPoints.append(hand[.indexTip]!.location)
            if let tip = HandDrawingGesture.drawingTip(in: hand, imageSize: imageSize) {
                drawing.append(tip)
            } else {
                drawing.endStroke()
            }
        }
        #expect(drawing.strokes.count == 1)
        #expect(drawing.strokes.first?.points == expectedPoints)
    }

    @Test func missingUncertainOrInvalidFingertipsStillPauseDrawing() {
        #expect(HandDrawingGesture.drawingTip(in: [:], imageSize: imageSize) == nil)
        #expect(HandDrawingGesture.drawingTip(in: openHand(), imageSize: .zero) == nil)
        #expect(HandDrawingGesture.drawingTip(in: openHand(), imageSize: CGSize(width: CGFloat.infinity, height: 1920)) == nil)
        var uncertainTip = pointingHand()
        uncertainTip[.indexTip] = HandLandmark(location: CGPoint(x: 0.4, y: 0.78), confidence: 0.5)
        #expect(HandDrawingGesture.drawingTip(in: uncertainTip, imageSize: imageSize) == nil)
        for location in [CGPoint(x: CGFloat.nan, y: 0.78), CGPoint(x: 0.4, y: CGFloat.infinity),
                         CGPoint(x: -0.1, y: 0.78), CGPoint(x: 1.1, y: 0.78),
                         CGPoint(x: 0.4, y: 1.1)] {
            let invalidTip = HandLandmark(location: location, confidence: 0.95)
            #expect(HandDrawingGesture.drawingTip(in: [.indexTip: invalidTip], imageSize: imageSize) == nil)
        }
    }

    @Test func closingHandOrLosingTrackingEndsInkWithoutConnectingTheNextStroke() {
        var drawing = Drawing()
        drawing.selectColor(.blue)
        func shiftedHand(_ hand: [Joint: HandLandmark], _ dx: CGFloat, _ dy: CGFloat) -> [Joint: HandLandmark] {
            hand.mapValues {
                HandLandmark(location: CGPoint(x: $0.location.x + dx, y: $0.location.y + dy),
                             confidence: $0.confidence)
            }
        }
        let frames = [openHand(), shiftedHand(openHand(), 0.04, 0), fistHand(), [:],
                      shiftedHand(pointingHand(), 0.2, 0.1), shiftedHand(pointingHand(), 0.24, 0.1)]
        for frame in frames {
            if let tip = HandDrawingGesture.drawingTip(in: frame, imageSize: imageSize) {
                drawing.append(tip)
            } else {
                drawing.endStroke()
            }
        }
        #expect(drawing.strokes.count == 2)
        #expect(drawing.strokes.allSatisfy { $0.color == .blue && $0.points.count == 2 })
        #expect(drawing.strokes[0].points == [openHand()[.indexTip]!.location,
                                             shiftedHand(openHand(), 0.04, 0)[.indexTip]!.location])
        #expect(drawing.strokes[1].points == [shiftedHand(pointingHand(), 0.2, 0.1)[.indexTip]!.location,
                                             shiftedHand(pointingHand(), 0.24, 0.1)[.indexTip]!.location])
    }

    private func pointingHand() -> [Joint: HandLandmark] {
        [
            .wrist: landmark(0.50, 0.16),
            .indexMCP: landmark(0.40, 0.40), .indexPIP: landmark(0.40, 0.58), .indexTip: landmark(0.40, 0.78),
            .middleMCP: landmark(0.50, 0.40), .middlePIP: landmark(0.50, 0.54), .middleTip: landmark(0.50, 0.38),
            .ringMCP: landmark(0.60, 0.40), .ringPIP: landmark(0.60, 0.51), .ringTip: landmark(0.60, 0.36),
            .littleMCP: landmark(0.70, 0.40), .littlePIP: landmark(0.70, 0.47), .littleTip: landmark(0.70, 0.35),
            .thumbMP: landmark(0.35, 0.30), .thumbIP: landmark(0.38, 0.37), .thumbTip: landmark(0.46, 0.34)
        ]
    }

    private func openHand() -> [Joint: HandLandmark] {
        var hand = pointingHand()
        for joints: (Joint, Joint, Joint) in [
            (.middleMCP, .middlePIP, .middleTip),
            (.ringMCP, .ringPIP, .ringTip),
            (.littleMCP, .littlePIP, .littleTip)
        ] {
            extend(joints, in: &hand)
        }
        hand[.thumbMP] = landmark(0.35, 0.30)
        hand[.thumbIP] = landmark(0.28, 0.39)
        hand[.thumbTip] = landmark(0.21, 0.48)
        return hand
    }

    private func fistHand() -> [Joint: HandLandmark] {
        var hand = pointingHand()
        hand[.indexTip] = landmark(0.4, 0.38)
        return hand
    }

    private func partlyOpenHand() -> [Joint: HandLandmark] {
        var hand = pointingHand()
        for joints: (Joint, Joint, Joint) in [
            (.indexMCP, .indexPIP, .indexTip),
            (.middleMCP, .middlePIP, .middleTip),
            (.ringMCP, .ringPIP, .ringTip),
            (.littleMCP, .littlePIP, .littleTip)
        ] {
            let base = hand[joints.0]!.location
            hand[joints.1] = landmark(base.x, base.y + 0.18)
            hand[joints.2] = landmark(base.x + 0.06, base.y + 0.18)
        }
        return hand
    }

    private func extend(_ joints: (Joint, Joint, Joint), in hand: inout [Joint: HandLandmark]) {
        let base = hand[joints.0]!.location
        hand[joints.1] = landmark(base.x, base.y + 0.18)
        hand[joints.2] = landmark(base.x, base.y + 0.36)
    }

    private func landmark(_ x: CGFloat, _ y: CGFloat) -> HandLandmark {
        HandLandmark(location: CGPoint(x: x, y: y), confidence: 0.95)
    }
}
