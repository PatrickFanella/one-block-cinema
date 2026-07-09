import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

struct CaptureView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = CameraCaptureController()
    @State private var showPhotoPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var reviewPlayer: AVPlayer?

    private var theme: FilmTheme {
        viewModel.activeSession?.theme ?? .documentary
    }

    private var aspectRatio: TemplateAspectRatio {
        viewModel.activeSession?.aspectRatio ?? .horizontal
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ZStack {
                    cameraSurface
                    compositionGuide
                    promptOverlay

                    if isProcessing {
                        Color.black.opacity(0.55)
                        ProgressView("Saving clip…")
                            .tint(CinemaColors.amber)
                            .foregroundStyle(CinemaColors.warmWhite)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                zoomControl
                bottomControls
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: 1,
            matching: .videos
        )
        .onChange(of: selectedItems) { _, newItems in
            guard let item = newItems.first else { return }
            Task { await handlePickedVideo(item) }
        }
        .onChange(of: camera.capturedURL) { _, url in
            reviewPlayer?.pause()
            reviewPlayer = url.map(AVPlayer.init(url:))
        }
        .task {
            await camera.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await camera.prepare() }
        }
        .onDisappear {
            reviewPlayer?.pause()
            camera.stopSession()
            camera.discardCapture()
        }
        .alert("Capture issue", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Try recording again or select a different library clip.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close camera")

            Spacer()

            if let prompt = viewModel.currentPrompt {
                VStack(spacing: 2) {
                    Text("SHOT \(prompt.index + 1)")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(theme.accentColor)
                    Text(prompt.direction)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    camera.toggleTorch()
                } label: {
                    Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .frame(width: 40, height: 44)
                }
                .disabled(!camera.isTorchAvailable || camera.isRecording || camera.capturedURL != nil)
                .accessibilityLabel(camera.isTorchOn ? "Turn torch off" : "Turn torch on")

                Button {
                    Task { await camera.setMicrophoneEnabled(!camera.microphoneEnabled) }
                } label: {
                    Image(systemName: camera.microphoneEnabled ? "mic.fill" : "mic.slash.fill")
                        .frame(width: 40, height: 44)
                }
                .disabled(camera.isRecording || camera.capturedURL != nil)
                .accessibilityLabel(camera.microphoneEnabled ? "Mute microphone" : "Enable microphone")

                Button {
                    Task { await camera.switchCamera() }
                } label: {
                    Image(systemName: "camera.rotate.fill")
                        .frame(width: 40, height: 44)
                }
                .disabled(camera.isRecording || camera.capturedURL != nil || camera.state != .ready)
                .accessibilityLabel("Switch camera")
            }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black)
    }

    @ViewBuilder
    private var cameraSurface: some View {
        if let reviewPlayer, camera.capturedURL != nil {
            VideoPlayer(player: reviewPlayer)
                .background(.black)
                .accessibilityLabel("Recorded clip review")
        } else {
            switch camera.state {
            case .ready:
                CameraPreview(session: camera.session) { devicePoint in
                    camera.focusAndExpose(at: devicePoint)
                }
                .ignoresSafeArea()
            case .requestingPermission, .idle:
                cameraMessage(icon: nil, title: "Preparing camera", message: "Checking camera and microphone access…")
            case .denied:
                cameraMessage(
                    icon: "camera.fill",
                    title: "Camera access is off",
                    message: "Enable camera access in Settings, or import a video from your library.",
                    showSettings: true
                )
            case .unavailable:
                cameraMessage(
                    icon: "camera.fill",
                    title: "Camera unavailable",
                    message: "Recording needs a compatible iPhone camera. Library import remains available."
                )
            case let .failed(message):
                cameraMessage(icon: "exclamationmark.triangle.fill", title: "Camera issue", message: message, showSettings: true)
            }
        }
    }

    private func cameraMessage(
        icon: String?,
        title: String,
        message: String,
        showSettings: Bool = false
    ) -> some View {
        VStack(spacing: 16) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 42))
                    .foregroundStyle(CinemaColors.amber)
            } else {
                ProgressView().tint(CinemaColors.amber)
            }
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(CinemaColors.warmWhite)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(CinemaColors.dimText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if showSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(CinemaColors.amber)
            }
            Button("Import from Library") { showPhotoPicker = true }
                .buttonStyle(.bordered)
                .tint(CinemaColors.warmWhite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.07))
    }

    private var compositionGuide: some View {
        GeometryReader { geometry in
            let maxWidth = geometry.size.width - 32
            let maxHeight = geometry.size.height - 32
            let desiredRatio = aspectRatio.widthToHeightRatio
            let width = min(maxWidth, maxHeight * desiredRatio)
            let height = width / desiredRatio

            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .frame(width: width, height: min(height, maxHeight))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .opacity(camera.capturedURL == nil ? 1 : 0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var promptOverlay: some View {
        if camera.capturedURL == nil, let prompt = viewModel.currentPrompt {
            VStack {
                Spacer()
                VStack(spacing: 4) {
                    Text(prompt.direction)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                    Text(prompt.hint)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.65))
                .clipShape(.rect(cornerRadius: 12))
                .padding(.bottom, 14)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var zoomControl: some View {
        if camera.state == .ready, camera.capturedURL == nil, camera.maximumZoomFactor > 1 {
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                Slider(
                    value: Binding(
                        get: { camera.zoomFactor },
                        set: { camera.setZoomFactor($0) }
                    ),
                    in: 1 ... camera.maximumZoomFactor
                )
                .tint(CinemaColors.amber)
                .accessibilityLabel("Camera zoom")
                .accessibilityValue(String(format: "%.1f times", camera.zoomFactor))
                Image(systemName: "plus.magnifyingglass")
                Text(String(format: "%.1f×", camera.zoomFactor))
                    .font(.caption.monospacedDigit())
                    .frame(width: 42)
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.black)
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        if camera.capturedURL != nil {
            HStack(spacing: 16) {
                Button {
                    reviewPlayer?.pause()
                    reviewPlayer = nil
                    camera.discardCapture()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button {
                    Task { await useRecordedClip() }
                } label: {
                    Label("Use Clip", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CinemaColors.amber)
                .disabled(isProcessing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.black)
        } else {
            HStack(spacing: 32) {
                Button {
                    showPhotoPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("Import").font(.caption2)
                    }
                    .frame(width: 58, height: 58)
                }
                .disabled(viewModel.currentPrompt == nil || isProcessing || camera.isRecording)

                recordButton

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .frame(width: 58, height: 58)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(.black)
        }
    }

    private var recordButton: some View {
        Button {
            camera.toggleRecording(rotationAngle: currentVideoRotationAngle)
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 74, height: 74)
                RoundedRectangle(cornerRadius: camera.isRecording ? 7 : 30)
                    .fill(.red)
                    .frame(width: camera.isRecording ? 34 : 58, height: camera.isRecording ? 34 : 58)
                    .animation(reduceMotion ? nil : .snappy, value: camera.isRecording)
            }
            .accessibilityLabel(camera.isRecording ? "Stop recording" : "Start recording")
        }
        .disabled(camera.state != .ready || viewModel.currentPrompt == nil || isProcessing)
        .opacity(camera.state == .ready && viewModel.currentPrompt != nil && !isProcessing ? 1 : 0.45)
    }

    private var currentVideoRotationAngle: CGFloat {
        switch UIDevice.current.orientation {
        case .landscapeLeft: 180
        case .landscapeRight: 0
        case .portraitUpsideDown: 270
        default: 90
        }
    }

    private func useRecordedClip() async {
        guard let promptId = viewModel.currentPrompt?.id, let url = camera.capturedURL else {
            showImportError(ClipImportError.noActiveSession)
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        if await viewModel.addClip(from: url, forPromptId: promptId) {
            _ = camera.takeCapture()
            try? FileManager.default.removeItem(at: url)
            dismiss()
        }
    }

    private func handlePickedVideo(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer {
            isProcessing = false
            selectedItems.removeAll()
        }

        guard let promptId = viewModel.currentPrompt?.id else {
            showImportError(ClipImportError.noActiveSession)
            return
        }

        do {
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                throw ClipImportError.noVideoSelected
            }
            defer { try? FileManager.default.removeItem(at: movie.url) }
            if await viewModel.addClip(from: movie.url, forPromptId: promptId) {
                dismiss()
            }
        } catch {
            showImportError(error)
        }
    }

    private func showImportError(_ error: Error) {
        viewModel.errorMessage = "Failed to save video: \(error.localizedDescription)"
        viewModel.showError = true
    }
}

nonisolated struct VideoTransferable: Transferable {
    let url: URL

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let destination = try ClipFileStore.makeImportedClipURL(for: received.file)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return VideoTransferable(url: destination)
        }
    }
}

nonisolated enum ClipFileStore {
    static func makeImportedClipURL(for sourceURL: URL) throws -> URL {
        let directory = try importedClipsDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        return directory.appendingPathComponent("clip_\(UUID().uuidString).\(fileExtension)")
    }

    private static func importedClipsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneBlockCinemaImports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
