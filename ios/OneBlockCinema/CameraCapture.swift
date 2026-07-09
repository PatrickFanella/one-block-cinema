@preconcurrency import AVFoundation
import Observation
import SwiftUI
import UIKit

nonisolated enum CameraCaptureState: Sendable, Equatable {
    case idle
    case requestingPermission
    case ready
    case denied
    case unavailable
    case failed(String)
}

@Observable
final nonisolated class CameraCaptureController: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "app.oneblockcinema.camera.session", qos: .userInitiated)

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var discardRecordingOnFinish = false

    private(set) var state: CameraCaptureState = .idle
    private(set) var isRecording = false
    private(set) var capturedURL: URL?
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var maximumZoomFactor: CGFloat = 1
    private(set) var zoomFactor: CGFloat = 1
    private(set) var isTorchAvailable = false
    private(set) var isTorchOn = false
    private(set) var microphoneEnabled = true

    @MainActor
    func prepare() async {
        guard state == .idle || state == .denied || state == .unavailable || isFailed else { return }
        state = .requestingPermission

        let videoAuthorized = await authorization(for: .video, requestIfNeeded: true)
        guard videoAuthorized else {
            state = .denied
            return
        }
        let audioAuthorized = await authorization(for: .audio, requestIfNeeded: true)
        microphoneEnabled = audioAuthorized

        do {
            let capabilities = try await configure(position: position, includeAudio: audioAuthorized)
            position = capabilities.position
            maximumZoomFactor = capabilities.maximumZoomFactor
            isTorchAvailable = capabilities.hasTorch
            isTorchOn = false
            zoomFactor = 1
            state = .ready
            await startSession()
        } catch CameraError.noCamera {
            state = .unavailable
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func toggleRecording(rotationAngle: CGFloat) {
        guard state == .ready else { return }
        if isRecording {
            stopRecording()
        } else {
            startRecording(rotationAngle: rotationAngle)
        }
    }

    @MainActor
    func switchCamera() async {
        guard state == .ready, !isRecording else { return }
        let requestedPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        do {
            let capabilities = try await configure(
                position: requestedPosition,
                includeAudio: microphoneEnabled
            )
            position = capabilities.position
            maximumZoomFactor = capabilities.maximumZoomFactor
            isTorchAvailable = capabilities.hasTorch
            isTorchOn = false
            zoomFactor = 1
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func toggleTorch() {
        guard state == .ready, isTorchAvailable, !isRecording else { return }
        let desired = !isTorchOn
        guard let device = videoInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = desired ? .on : .off
                device.unlockForConfiguration()
                Task { @MainActor [weak self] in self?.isTorchOn = desired }
            } catch {
                Task { @MainActor [weak self] in self?.state = .failed(error.localizedDescription) }
            }
        }
    }

    @MainActor
    func setMicrophoneEnabled(_ enabled: Bool) async {
        guard !isRecording else { return }
        if enabled {
            guard await authorization(for: .audio, requestIfNeeded: true) else {
                microphoneEnabled = false
                return
            }
        }
        do {
            let capabilities = try await configure(position: position, includeAudio: enabled)
            microphoneEnabled = enabled
            position = capabilities.position
            maximumZoomFactor = capabilities.maximumZoomFactor
            isTorchAvailable = capabilities.hasTorch
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func setZoomFactor(_ factor: CGFloat) {
        guard state == .ready, let device = videoInput?.device else { return }
        let clamped = min(max(factor, 1), maximumZoomFactor)
        zoomFactor = clamped
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor [weak self] in self?.state = .failed(error.localizedDescription) }
            }
        }
    }

    @MainActor
    func focusAndExpose(at devicePoint: CGPoint) {
        guard state == .ready, let device = videoInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = device.isFocusModeSupported(.continuousAutoFocus) ? .continuousAutoFocus : .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = device.isExposureModeSupported(.continuousAutoExposure) ? .continuousAutoExposure : .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor [weak self] in self?.state = .failed(error.localizedDescription) }
            }
        }
    }

    @MainActor
    func discardCapture() {
        guard let capturedURL else { return }
        try? FileManager.default.removeItem(at: capturedURL)
        self.capturedURL = nil
    }

    @MainActor
    func takeCapture() -> URL? {
        let url = capturedURL
        capturedURL = nil
        return url
    }

    @MainActor
    func stopSession() {
        if isRecording {
            discardRecordingOnFinish = true
            stopRecording()
        }
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    nonisolated func fileOutput(
        _: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from _: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isRecording = false
            if discardRecordingOnFinish {
                discardRecordingOnFinish = false
                try? FileManager.default.removeItem(at: outputFileURL)
            } else if let error {
                try? FileManager.default.removeItem(at: outputFileURL)
                state = .failed(error.localizedDescription)
            } else {
                capturedURL = outputFileURL
            }
        }
    }

    @MainActor
    private func startRecording(rotationAngle: CGFloat) {
        guard !movieOutput.isRecording else { return }
        discardRecordingOnFinish = false
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneBlockCinemaCapture-\(UUID().uuidString).mov")
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        movieOutput.maxRecordedDuration = CMTime(seconds: VideoExportLimits.maximumDuration, preferredTimescale: 600)
        isRecording = true
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    @MainActor
    private func stopRecording() {
        guard movieOutput.isRecording else {
            isRecording = false
            return
        }
        movieOutput.stopRecording()
    }

    @MainActor
    private func authorization(for mediaType: AVMediaType, requestIfNeeded: Bool) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            true
        case .notDetermined where requestIfNeeded:
            await AVCaptureDevice.requestAccess(for: mediaType)
        default:
            false
        }
    }

    private func configure(
        position requestedPosition: AVCaptureDevice.Position,
        includeAudio: Bool
    ) async throws -> CameraCapabilities {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    session.beginConfiguration()
                    defer { session.commitConfiguration() }
                    session.sessionPreset = .hd1920x1080

                    if let videoInput {
                        session.removeInput(videoInput)
                    }
                    if let audioInput {
                        session.removeInput(audioInput)
                    }

                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: requestedPosition)
                        ?? AVCaptureDevice.default(for: .video)
                    guard let device else { throw CameraError.noCamera }

                    let newVideoInput = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(newVideoInput) else { throw CameraError.cannotAddVideoInput }
                    session.addInput(newVideoInput)
                    videoInput = newVideoInput

                    if includeAudio,
                       let microphone = AVCaptureDevice.default(for: .audio)
                    {
                        let newAudioInput = try AVCaptureDeviceInput(device: microphone)
                        if session.canAddInput(newAudioInput) {
                            session.addInput(newAudioInput)
                            audioInput = newAudioInput
                        } else {
                            audioInput = nil
                        }
                    } else {
                        audioInput = nil
                    }

                    if !session.outputs.contains(movieOutput) {
                        guard session.canAddOutput(movieOutput) else { throw CameraError.cannotAddMovieOutput }
                        session.addOutput(movieOutput)
                    }

                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.videoZoomFactor = 1
                    device.unlockForConfiguration()

                    continuation.resume(
                        returning: CameraCapabilities(
                            position: device.position,
                            maximumZoomFactor: min(max(device.activeFormat.videoMaxZoomFactor, 1), 6),
                            hasTorch: device.hasTorch && device.position == .back
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }
}

private nonisolated struct CameraCapabilities: Sendable {
    let position: AVCaptureDevice.Position
    let maximumZoomFactor: CGFloat
    let hasTorch: Bool
}

private nonisolated enum CameraError: LocalizedError, Sendable {
    case noCamera
    case cannotAddVideoInput
    case cannotAddMovieOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: "No compatible camera is available on this device."
        case .cannotAddVideoInput: "The camera input could not be configured."
        case .cannotAddMovieOutput: "Video recording could not be configured."
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let focus: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focus: focus)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        view.addGestureRecognizer(gesture)
        context.coordinator.previewView = view
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.focus = focus
    }

    final class Coordinator: NSObject {
        weak var previewView: CameraPreviewView?
        var focus: (CGPoint) -> Void

        init(focus: @escaping (CGPoint) -> Void) {
            self.focus = focus
        }

        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView else { return }
            let point = gesture.location(in: previewView)
            focus(previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }
}

final class CameraPreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("CameraPreviewView must use AVCaptureVideoPreviewLayer")
        }
        return previewLayer
    }
}
