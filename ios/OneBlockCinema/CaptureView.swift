import SwiftUI
import AVFoundation
import PhotosUI

struct CaptureView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker: Bool = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var recordingPulse: Bool = false
    @State private var isProcessing: Bool = false

    private var theme: FilmTheme { viewModel.activeSession?.theme ?? .documentary }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ZStack {
                    cameraPlaceholder

                    letterboxOverlay
                    crosshairOverlay

                    if isProcessing {
                        ProgressView()
                            .tint(CinemaColors.amber)
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomControls
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItems, maxSelectionCount: 1, matching: .videos)
        .onChange(of: selectedItems) { _, newItems in
            guard let item = newItems.first else { return }
            Task { await handlePickedVideo(item) }
        }
        .alert("Import issue", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Try selecting a different video clip.")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

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
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black)
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(CinemaColors.dimText)

            Text("Camera Preview")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(CinemaColors.warmWhite)

            Text("Install this app on your device\nvia the Rork App to use the camera.")
                .font(.subheadline)
                .foregroundStyle(CinemaColors.dimText)
                .multilineTextAlignment(.center)

            promptImportState

            Button {
                showPhotoPicker = true
            } label: {
                Label("Import from Library", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(CinemaColors.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(CinemaColors.amber)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            .disabled(viewModel.currentPrompt == nil || isProcessing)
            .opacity(viewModel.currentPrompt == nil || isProcessing ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
    }

    @ViewBuilder
    private var promptImportState: some View {
        if let prompt = viewModel.currentPrompt {
            VStack(spacing: 6) {
                Text("Importing attaches to Shot \(prompt.index + 1)")
                    .font(.caption)
                    .foregroundStyle(CinemaColors.warmWhite)

                if let clip = viewModel.currentPromptClip {
                    Text(clip.duration > 0 ? "A clip is attached — importing replaces it." : "Imported clip attached — importing replaces it.")
                        .font(.caption2)
                        .foregroundStyle(CinemaColors.amber)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No clip attached to this prompt yet.")
                        .font(.caption2)
                        .foregroundStyle(CinemaColors.dimText)
                }
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 6) {
                Text("No shot selected")
                    .font(.caption)
                    .foregroundStyle(CinemaColors.warmWhite)
                Text("Go back and choose a prompt before importing a clip.")
                    .font(.caption2)
                    .foregroundStyle(CinemaColors.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
    }

    private var letterboxOverlay: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.black)
                .frame(height: 40)

            Spacer()

            Rectangle()
                .fill(.black)
                .frame(height: 40)
        }
        .allowsHitTesting(false)
    }

    private var crosshairOverlay: some View {
        ZStack {
            Rectangle()
                .stroke(theme.accentColor.opacity(0.3), lineWidth: 0.5)
                .frame(width: 1, height: 30)

            Rectangle()
                .stroke(theme.accentColor.opacity(0.3), lineWidth: 0.5)
                .frame(width: 30, height: 1)

            Rectangle()
                .stroke(theme.accentColor.opacity(0.15), lineWidth: 0.5)
                .padding(60)
        }
        .allowsHitTesting(false)
    }

    private var bottomControls: some View {
        HStack(spacing: 32) {
            Button {
                showPhotoPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 50, height: 50)
            }
            .disabled(viewModel.currentPrompt == nil || isProcessing)
            .opacity(viewModel.currentPrompt == nil || isProcessing ? 0.5 : 1)

            recordButton

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(CinemaColors.amber)
                    .frame(width: 50, height: 50)
            }
        }
        .padding(.vertical, 20)
        .background(.black)
    }

    private var recordButton: some View {
        Button {
            // Camera not available in simulator
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 3)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color.red)
                    .frame(width: 58, height: 58)
                    .scaleEffect(recordingPulse ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingPulse)
            }
        }
        .onAppear { recordingPulse = true }
        .disabled(true)
        .opacity(0.55)
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
            if await viewModel.addClip(from: movie.url, forPromptId: promptId) {
                dismiss()
            }
        } catch {
            showImportError(error)
        }
    }

    private func showImportError(_ error: Error) {
        viewModel.errorMessage = "Failed to import video: \(error.localizedDescription)"
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
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("ImportedClips", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
