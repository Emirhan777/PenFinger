import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            ZStack {
                CameraView(camera: camera)
                DrawingView(points: camera.drawPoints)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            if let message = camera.cameraMessage {
                VStack(spacing: 16) {
                    Text(message)
                        .multilineTextAlignment(.center)
                    if camera.needsCameraAccess {
                        Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                            .font(.headline)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(32)
            }

            VStack {
                Spacer()
                ZStack {
                    Button("Clean", action: camera.clear)
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .disabled(camera.isCapturing)

                    HStack {
                        Spacer()
                        Button(action: camera.takePhoto) {
                            ZStack {
                                Circle().fill(.white)
                                if camera.isCapturing {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 2))
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                            .opacity(camera.isReady ? 1 : 0.5)
                        }
                        .disabled(!camera.isReady || camera.isCapturing)
                        .accessibilityLabel("Take photo")
                        .accessibilityHint("Capture the camera view with your drawing")
                        .accessibilityIdentifier("takePhotoButton")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(.black)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                camera.start()
            } else {
                camera.stop()
            }
        }
        .sheet(item: $camera.capturedPhoto) { photo in
            PhotoPreview(photo: photo)
        }
        .alert(item: $camera.captureAlert) { alert in
            Alert(title: Text("Couldn't take photo"), message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

struct DrawingView: View {
    // Points are normalized to the visible camera area, including its aspect-fill crop.
    let points: [CGPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1, let first = points.first else { return }
            var path = Path()
            path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
            context.stroke(path, with: .color(.black), lineWidth: PhotoRenderer.lineWidth)
        }
    }
}

struct CameraView: UIViewRepresentable {
    let camera: CameraController

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        #if DEBUG && targetEnvironment(simulator)
        // A simulated camera has no hardware session to attach to the preview.
        if !ProcessInfo.processInfo.arguments.contains("--uitest-camera") {
            view.previewLayer.session = camera.session
        }
        #else
        view.previewLayer.session = camera.session
        #endif
        view.previewLayer.videoGravity = .resizeAspectFill
        camera.previewLayer = view.previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setNeedsLayout()
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let connection = previewLayer.connection,
              let orientation = window?.windowScene?.interfaceOrientation else { return }
        let angle: CGFloat
        switch orientation {
        case .landscapeRight: angle = 0
        case .landscapeLeft: angle = 180
        case .portraitUpsideDown: angle = 270
        default: angle = 90
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
