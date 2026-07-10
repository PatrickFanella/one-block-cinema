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
    case recovering(CameraInterruption)
    case interrupted(CameraInterruption)
    case failed(String)
}

nonisolated enum CameraRecoveryEvent: Sendable, Equatable {
    case interruptionBegan(CameraInterruption)
    case interruptionEnded
    case mediaServicesReset
    case recoverySucceeded
    case recoveryFailed(String)
}

nonisolated enum CameraRecoveryStateMachine {
    static func transition(from state: CameraCaptureState, event: CameraRecoveryEvent) -> CameraCaptureState {
        switch event {
        case let .interruptionBegan(reason): .interrupted(reason)
        case .interruptionEnded:
            if case let .interrupted(reason) = state {
                .recovering(reason)
            } else {
                state
            }
        case .mediaServicesReset: .recovering(.mediaServicesReset)
        case .recoverySucceeded: .ready
        case let .recoveryFailed(message): .failed(message)
        }
    }
}

@Observable
final nonisolated class CameraCaptureController: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "app.oneblockcinema.camera.session", qos: .userInitiated)

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var discardRecordingOnFinish = false
    private var notificationTokens: [NSObjectProtocol] = []
    private let storageCapacityProvider: any StorageCapacityProviding
    private let thermalStateProvider: any ThermalStateProviding
    private let storagePolicy: StorageBudgetPolicy
    private var storageMonitorTask: Task<Void, Never>?

    private(set) var state: CameraCaptureState = .idle
    private(set) var isRecording = false
    private(set) var capturedURL: URL?
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var maximumZoomFactor: CGFloat = 1
    private(set) var zoomFactor: CGFloat = 1
    private(set) var isTorchAvailable = false
    private(set) var isTorchOn = false
    private(set) var microphoneEnabled = true
    private(set) var conditionWarning: String?
    private(set) var latestInterruption: CameraInterruption?

    init(
        storageCapacityProvider: any StorageCapacityProviding = SystemStorageCapacityProvider(),
        thermalStateProvider: any ThermalStateProviding = SystemThermalStateProvider(),
        storagePolicy: StorageBudgetPolicy = StorageBudgetPolicy()
    ) {
        self.storageCapacityProvider = storageCapacityProvider
        self.thermalStateProvider = thermalStateProvider
        self.storagePolicy = storagePolicy
        super.init()
        observeSessionEvents()
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        storageMonitorTask?.cancel()
    }

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
            handleThermalChange()
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

    @MainActor
    func suspend() {
        latestInterruption = .appInactive
        state = CameraRecoveryStateMachine.transition(from: state, event: .interruptionBegan(.appInactive))
        if isRecording {
            stopRecording()
        }
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    @MainActor
    func resume() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            state = .denied
            return
        }
        let reason = latestInterruption ?? .appInactive
        state = .recovering(reason)
        await startSession()
        state = .ready
    }

    @MainActor
    func activate() async {
        if videoInput == nil || AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            state = .idle
            await prepare()
        } else {
            await resume()
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
            storageMonitorTask?.cancel()
            storageMonitorTask = nil
            if discardRecordingOnFinish {
                discardRecordingOnFinish = false
                try? FileManager.default.removeItem(at: outputFileURL)
            } else if let error {
                let nsError = error as NSError
                let finished = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
                if finished, await Self.isPlayableRecording(outputFileURL) {
                    capturedURL = outputFileURL
                } else {
                    try? FileManager.default.removeItem(at: outputFileURL)
                    state = .failed("Recording was interrupted. Try again or import a video.")
                }
            } else {
                if await Self.isPlayableRecording(outputFileURL) {
                    capturedURL = outputFileURL
                } else {
                    try? FileManager.default.removeItem(at: outputFileURL)
                    state = .failed("The recording could not be read. Try again or import a video.")
                }
            }
        }
    }

    @MainActor
    private func startRecording(rotationAngle: CGFloat) {
        guard !movieOutput.isRecording else { return }
        if thermalStateProvider.thermalState == .critical {
            conditionWarning = "This device is too hot to record. Let it cool down, then try again."
            state = .interrupted(.systemPressure)
            return
        }
        do {
            if let available = try storageCapacityProvider.availableCapacity(at: FileManager.default.temporaryDirectory),
               !storagePolicy.canStartCapture(availableBytes: available)
            {
                state = .failed("Recording needs at least 500 MB of free storage. Free space or import a clip.")
                return
            }
        } catch {
            conditionWarning = "Free storage could not be checked."
        }
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
        monitorStorageWhileRecording()
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

    private func observeSessionEvents() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] note in
                let reason = Self.interruptionReason(from: note)
                Task { @MainActor [weak self] in self?.handleInterruption(reason) }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in await self?.recoverAfterInterruption() }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                Task { @MainActor [weak self] in
                    if error?.code == .mediaServicesWereReset {
                        self?.state = CameraRecoveryStateMachine.transition(from: self?.state ?? .idle, event: .mediaServicesReset)
                        self?.latestInterruption = .mediaServicesReset
                        await self?.recoverAfterInterruption()
                    } else if let error {
                        self?.state = .failed(error.localizedDescription)
                    }
                }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleThermalChange() }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil) { [weak self] note in
                guard let device = note.object as? AVCaptureDevice else { return }
                Task { @MainActor [weak self] in
                    guard self?.videoInput?.device.uniqueID == device.uniqueID else { return }
                    self?.handleInterruption(.deviceDisconnected)
                }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.latestInterruption == .deviceDisconnected else { return }
                    await self?.recoverAfterInterruption()
                }
            }
        )
    }

    @MainActor
    private func handleInterruption(_ reason: CameraInterruption) {
        latestInterruption = reason
        state = CameraRecoveryStateMachine.transition(from: state, event: .interruptionBegan(reason))
        if isRecording {
            stopRecording()
        }
    }

    @MainActor
    private func recoverAfterInterruption() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            state = .denied
            return
        }
        state = CameraRecoveryStateMachine.transition(from: state, event: .interruptionEnded)
        await startSession()
        state = CameraRecoveryStateMachine.transition(from: state, event: .recoverySucceeded)
    }

    @MainActor
    private func handleThermalChange() {
        switch thermalStateProvider.thermalState {
        case .nominal, .fair:
            conditionWarning = nil
        case .serious:
            conditionWarning = "This device is getting hot. The torch was turned off."
            turnTorchOff()
        case .critical:
            conditionWarning = "Camera stopped because this device is too hot. Let it cool down, then retry."
            turnTorchOff()
            handleInterruption(.systemPressure)
        }
    }

    @MainActor
    private func turnTorchOff() {
        guard isTorchOn, let device = videoInput?.device else { return }
        sessionQueue.async {
            try? device.lockForConfiguration()
            if device.isTorchActive {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            Task { @MainActor [weak self] in self?.isTorchOn = false }
        }
    }

    @MainActor
    private func monitorStorageWhileRecording() {
        storageMonitorTask?.cancel()
        storageMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, isRecording else { return }
                guard let available = try? storageCapacityProvider.availableCapacity(at: FileManager.default.temporaryDirectory),
                      storagePolicy.shouldStopCapture(availableBytes: available)
                else { continue }
                conditionWarning = "Recording stopped because storage is nearly full."
                stopRecording()
                return
            }
        }
    }

    private static func interruptionReason(from notification: Notification) -> CameraInterruption {
        guard let rawValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber,
              let reason = AVCaptureSession.InterruptionReason(rawValue: rawValue.intValue)
        else { return .unknown }
        switch reason {
        case .audioDeviceInUseByAnotherClient: return .audioDeviceInUse
        case .videoDeviceInUseByAnotherClient: return .videoDeviceInUse
        case .videoDeviceNotAvailableWithMultipleForegroundApps: return .multipleForegroundApps
        case .videoDeviceNotAvailableDueToSystemPressure: return .systemPressure
        case .videoDeviceNotAvailableInBackground: return .appInactive
        case .sensitiveContentMitigationActivated: return .systemPressure
        @unknown default: return .unknown
        }
    }

    private static func isPlayableRecording(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty,
              let duration = try? await asset.load(.duration)
        else { return false }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite && seconds > 0
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
