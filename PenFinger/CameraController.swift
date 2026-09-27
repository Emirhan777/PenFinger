import AVFoundation
import SwiftUI
import Vision

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    @Published private(set) var drawPoints: [CGPoint] = []
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var cameraMessage: String?
    @Published private(set) var needsCameraAccess = false
    @Published var capturedPhoto: CapturedPhoto?
    @Published var captureAlert: CaptureAlert?

    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let visionQueue = DispatchQueue(label: "camera.vision")
    private let photoOutput = AVCapturePhotoOutput()
    private let handRequest = VNDetectHumanHandPoseRequest()
    // Configuration and photo delegates are confined to sessionQueue.
    private var configured = false
    private var photoDelegates: [Int64: PhotoCaptureDelegate] = [:]
    // UI state, including this flag and the preview layer, is used on the main thread.
    private var wantsToRun = false
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        handRequest.maximumHandCount = 1
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                                            object: session, queue: .main) { [weak self] _ in
            self?.isReady = false
            self?.cameraMessage = "The camera is temporarily unavailable. Try again in a moment."
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
                                            object: session, queue: .main) { [weak self] _ in
            guard let self, self.wantsToRun else { return }
            self.start()
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                            object: session, queue: .main) { [weak self] _ in
            self?.isReady = false
            self?.cameraMessage = "The camera stopped. Reopen the app to try again."
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        wantsToRun = true
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--uitest-camera") {
            cameraMessage = nil
            needsCameraAccess = false
            isReady = true
            if fixturePhoto == nil {
                fixturePhoto = makeFixturePhoto()
                drawPoints = [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.8, y: 0.5)]
            }
            return
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            needsCameraAccess = false
            cameraMessage = nil
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.wantsToRun else { return }
                    self.start()
                }
            }
        default:
            isReady = false
            needsCameraAccess = true
            cameraMessage = "Allow camera access in Settings to draw and take photos."
        }
    }

    func stop() {
        wantsToRun = false
        isReady = false
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func startSession() {
        sessionQueue.async { [self] in
            do {
                if !configured { try configureSession() }
                if !session.isRunning { session.startRunning() }
                let running = session.isRunning && !session.isInterrupted
                DispatchQueue.main.async {
                    guard self.wantsToRun else { return }
                    self.isReady = running
                    self.cameraMessage = running ? nil : "The camera is unavailable. Reopen the app to try again."
                }
            } catch {
                DispatchQueue.main.async {
                    self.isReady = false
                    self.cameraMessage = error.localizedDescription
                }
            }
        }
    }

    private func configureSession() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)
        guard session.canAddOutput(videoOutput), session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            throw CameraError.unavailable
        }
        session.addOutput(videoOutput)
        session.addOutput(photoOutput)
        // Keep the buffers unrotated; Vision receives its orientation separately.
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }
        configured = true
    }

    func clear() {
        drawPoints.removeAll()
    }

    func takePhoto() {
        guard isReady, !isCapturing else { return }
        #if DEBUG && targetEnvironment(simulator)
        if let fixturePhoto {
            isCapturing = true
            // An unattached simulator preview layer has no capture geometry.
            let size = previewLayer?.bounds.size ?? .zero
            let viewportSize = size.width > 0 && size.height > 0 ? size : fixturePhoto.size
            if ProcessInfo.processInfo.arguments.contains("--uitest-capture-failure") {
                finishCapture(.failure(CameraError.captureFailed))
            } else if let image = PhotoRenderer.render(photo: fixturePhoto, points: drawPoints, viewportSize: viewportSize) {
                finishCapture(.success(image))
            } else {
                finishCapture(.failure(CameraError.captureFailed))
            }
            return
        }
        #endif

        guard let previewLayer, previewLayer.bounds.width > 0, previewLayer.bounds.height > 0 else { return }
        let points = drawPoints
        let viewportSize = previewLayer.bounds.size
        let rotation = previewLayer.connection?.videoRotationAngle ?? 90
        isCapturing = true

        sessionQueue.async { [self] in
            guard session.isRunning, let connection = photoOutput.connection(with: .video),
                  connection.isActive, connection.isEnabled else {
                DispatchQueue.main.async { self.finishCapture(.failure(CameraError.unavailable)) }
                return
            }
            if connection.isVideoRotationAngleSupported(rotation) {
                connection.videoRotationAngle = rotation
            }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = .speed
            let id = settings.uniqueID
            let delegate = PhotoCaptureDelegate(points: points, viewportSize: viewportSize) { [weak self] result in
                guard let self else { return }
                self.sessionQueue.async { self.photoDelegates[id] = nil }
                DispatchQueue.main.async { self.finishCapture(result) }
            }
            photoDelegates[id] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func finishCapture(_ result: Result<UIImage, Error>) {
        isCapturing = false
        switch result {
        case .success(let image): capturedPhoto = CapturedPhoto(image: image)
        case .failure(let error): captureAlert = CaptureAlert(message: error.localizedDescription)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([handRequest])
            guard let observation = handRequest.results?.first,
                  let tip = try observation.recognizedPoints(.indexFinger)[.indexTip],
                  tip.confidence > 0.6 else { return }
            // Undo Vision's clockwise rotation and bottom-left origin to obtain
            // the native sensor coordinates expected by the preview layer.
            let devicePoint = CGPoint(x: 1 - tip.location.y, y: 1 - tip.location.x)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isReady, !self.isCapturing, self.capturedPhoto == nil,
                      let preview = self.previewLayer,
                      preview.bounds.width > 0, preview.bounds.height > 0 else { return }
                let point = preview.layerPointConverted(fromCaptureDevicePoint: devicePoint)
                self.drawPoints.append(CGPoint(x: point.x / preview.bounds.width,
                                               y: point.y / preview.bounds.height))
                if self.drawPoints.count > 3000 { self.drawPoints.removeFirst() }
            }
        } catch {
            // A missed hand observation should not interrupt the camera or photo capture.
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    private var fixturePhoto: UIImage?

    private func makeFixturePhoto() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
    }
    #endif
}

private enum CameraError: LocalizedError {
    case unavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The camera is unavailable. Try again when the camera is ready."
        case .captureFailed: return "The photo couldn't be captured. Please try again."
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let points: [CGPoint]
    let viewportSize: CGSize
    let completion: (Result<UIImage, Error>) -> Void
    private var result: Result<UIImage, Error>?

    init(points: [CGPoint], viewportSize: CGSize, completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.points = points
        self.viewportSize = viewportSize
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let photoImage = UIImage(data: data),
                  let image = PhotoRenderer.render(photo: photoImage, points: points, viewportSize: viewportSize) {
            result = .success(image)
        } else {
            result = .failure(CameraError.captureFailed)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        completion(error.map { .failure($0) } ?? result ?? .failure(CameraError.captureFailed))
    }
}
