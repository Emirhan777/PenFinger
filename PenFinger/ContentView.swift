import SwiftUI
import AVFoundation
import Vision

// MARK: - MAIN VIEW

struct ContentView: View {
    @StateObject private var processor = HandPoseProcessor()

    var body: some View {
        ZStack {
            CameraView(processor: processor)
                .ignoresSafeArea()

            DrawingView(points: processor.drawPoints)
                .ignoresSafeArea()

            VStack {
                Spacer()

                Button(action: {
                    processor.clear()
                }) {
                    Text("Clean")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - CAMERA VIEW

struct CameraView: UIViewRepresentable {
    let processor: HandPoseProcessor

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return view }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(
            processor,
            queue: DispatchQueue(label: "camera.queue")
        )
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        view.layer.addSublayer(preview)
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - DRAWING VIEW

struct DrawingView: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points.first!)

            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(.black),
                lineWidth: 4
            )
        }
    }
}

// MARK: - HAND POSE PROCESSOR

class HandPoseProcessor: NSObject,
                          ObservableObject,
                          AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var drawPoints: [CGPoint] = []

    private let request = VNDetectHumanHandPoseRequest()

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else { return }

            let points = try observation.recognizedPoints(.indexFinger)

            guard let tip = points[.indexTip],
                  tip.confidence > 0.6 else { return }

            DispatchQueue.main.async {
                let screenPoint = self.convertToScreen(point: tip.location)
                self.drawPoints.append(screenPoint)

                // Safety limit
                if self.drawPoints.count > 3000 {
                    self.drawPoints.removeFirst()
                }
            }

        } catch {
            print("Hand pose error:", error)
        }
    }

    private func convertToScreen(point: CGPoint) -> CGPoint {
        let screen = UIScreen.main.bounds
        return CGPoint(
            x: point.x * screen.width,
            y: (1 - point.y) * screen.height
        )
    }

    func clear() {
        drawPoints.removeAll()
    }
}
