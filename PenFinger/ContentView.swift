import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showColors = false

    var body: some View {
        ZStack {
            ZStack {
                CameraView(camera: camera)
                DrawingView(strokes: camera.drawing.strokes)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { showColors = false }
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
                HStack(spacing: 8) {
                    Button {
                        showColors.toggle()
                    } label: {
                        Circle()
                            .fill(camera.drawing.color.color)
                            .frame(width: 48, height: 48)
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Drawing color")
                    .accessibilityValue(camera.drawing.color.rawValue)
                    .accessibilityHint("Choose the color for new strokes")
                    .accessibilityIdentifier("drawingColorButton")

                    Spacer(minLength: 0)
                    Button("Clean") {
                        showColors = false
                        camera.clear()
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                    Spacer(minLength: 0)
                    Button {
                        showColors = false
                        camera.takePhoto()
                    } label: {
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
                    .accessibilityHint("Save the camera view with your drawing to Photos and show a preview")
                    .accessibilityIdentifier("takePhotoButton")
                }
                .overlay(alignment: .bottomLeading) {
                    if showColors {
                        InkColorPalette(selectedColor: camera.drawing.color) { color in
                            camera.selectColor(color)
                            showColors = false
                        }
                        .fixedSize()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        .padding(.bottom, 76)
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
            PhotoPreview(photo: photo, saveStatus: camera.photoSaveStatus)
        }
        .alert(item: $camera.captureAlert) { alert in
            Alert(title: Text("Couldn't take photo"), message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

private struct InkColorPalette: View {
    let selectedColor: InkColor
    let onSelect: (InkColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drawing color")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 12), count: 4), spacing: 12) {
                ForEach(InkColor.allCases) { color in
                    Button {
                        onSelect(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(.gray, lineWidth: 1))
                            .overlay {
                                if color == selectedColor {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(checkmarkColor(for: color))
                                }
                            }
                            .frame(width: 48, height: 48)
                            .overlay {
                                if color == selectedColor {
                                    Circle().strokeBorder(.primary, lineWidth: 2)
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.rawValue)
                    .accessibilityAddTraits(color == selectedColor ? .isSelected : [])
                    .accessibilityIdentifier("inkColor-\(color.rawValue)")
                }
            }
        }
        .frame(width: 228)
        .padding(16)
    }

    private func checkmarkColor(for color: InkColor) -> Color {
        switch color {
        case .black, .red, .blue, .purple: .white
        case .white, .orange, .yellow, .green: .black
        }
    }
}

struct DrawingView: View {
    // Points are normalized to the visible camera area, including its aspect-fill crop.
    let strokes: [DrawingStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                guard stroke.points.count > 1, let first = stroke.points.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for point in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                }
                context.stroke(path, with: .color(stroke.color.color), lineWidth: PhotoRenderer.lineWidth)
            }
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
