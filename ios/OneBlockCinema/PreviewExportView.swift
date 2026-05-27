import SwiftUI
import AVKit

struct PreviewExportView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var currentClipIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var playbackTimer: Timer?

    private var session: FilmSession? { viewModel.activeSession }
    private var theme: FilmTheme { session?.theme ?? .documentary }
    private var exportPlan: VideoExportPlan? {
        guard let session else { return nil }
        return VideoExportLimits.plan(for: session.clips)
    }

    var body: some View {
        ZStack {
            CinemaColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                videoPlayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                controlsOverlay
            }
        }
        .overlay { FilmGrainView() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("PREVIEW")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(CinemaColors.amber)
            }
        }
        .alert("Export Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.exportedVideoURL {
                ShareSheet(items: [url])
            }
        }
        .onChange(of: viewModel.showExportShare) { _, show in
            if show {
                showShareSheet = true
                viewModel.showExportShare = false
            }
        }
    }

    private var videoPlayer: some View {
        ZStack {
            Color.black

            if let session, !session.clips.isEmpty {
                let orderedClips = session.clipsInPromptOrder
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.08))
                            .aspectRatio(16/9, contentMode: .fit)

                        VStack(spacing: 12) {
                            if currentClipIndex < orderedClips.count {
                                let clip = orderedClips[currentClipIndex]
                                Image(systemName: "film")
                                    .font(.system(size: 40))
                                    .foregroundStyle(theme.accentColor.opacity(0.4))

                                if let prompt = session.prompts.first(where: { $0.id == clip.promptId }) {
                                    Text("Shot \(prompt.index + 1)")
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundStyle(theme.accentColor)
                                }

                                Text("Basic preview · no trim, titles, transitions, or soundtrack controls yet")
                                    .font(.caption)
                                    .foregroundStyle(CinemaColors.dimText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    timelineBar(session)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(CinemaColors.surfaceLight)
                    Text("No clips to preview")
                        .font(.subheadline)
                        .foregroundStyle(CinemaColors.dimText)
                }
            }
        }
    }

    private func timelineBar(_ session: FilmSession) -> some View {
        let orderedClips = session.clipsInPromptOrder
        HStack(spacing: 3) {
            ForEach(Array(orderedClips.enumerated()), id: \.element.id) { index, _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == currentClipIndex ? CinemaColors.amber : CinemaColors.surfaceLight)
                    .frame(height: 4)
                    .onTapGesture {
                        withAnimation(.snappy) {
                            currentClipIndex = index
                        }
                    }
            }
        }
        .padding(.horizontal, 24)
    }

    private var controlsOverlay: some View {
        VStack(spacing: 16) {
            exportStateCard

            HStack(spacing: 24) {
                Button {
                    guard let session, currentClipIndex > 0 else { return }
                    withAnimation(.snappy) { currentClipIndex -= 1 }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundStyle(CinemaColors.warmWhite)
                }

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(CinemaColors.amber)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 64, height: 64)
                        .background(CinemaColors.surface)
                        .clipShape(Circle())
                        .shadow(color: CinemaColors.amberGlow, radius: 8)
                }

                Button {
                    guard let session, currentClipIndex < session.clipsInPromptOrder.count - 1 else { return }
                    withAnimation(.snappy) { currentClipIndex += 1 }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundStyle(CinemaColors.warmWhite)
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.exportVideo() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isExporting {
                            ProgressView()
                                .tint(CinemaColors.background)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(viewModel.isExporting ? "Exporting..." : "Export & Share")
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                    }
                    .foregroundStyle(CinemaColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CinemaColors.amber)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(viewModel.isExporting || exportPlan?.segments.isEmpty != false)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [.clear, CinemaColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var exportStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: exportStateIcon)
                    .foregroundStyle(exportStateTint)
                Text(exportStateTitle)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(CinemaColors.warmWhite)
                Spacer()
                if let plan = exportPlan, plan.totalDuration > 0 {
                    Text("\(formattedDuration(plan.totalDuration)) / \(formattedDuration(VideoExportLimits.maximumDuration))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(CinemaColors.dimText)
                }
            }

            ProgressView(value: viewModel.isExporting ? viewModel.exportProgress : exportPlanProgress)
                .tint(exportStateTint)

            Text(exportStateMessage)
                .font(.caption2)
                .foregroundStyle(CinemaColors.dimText)
        }
        .padding(12)
        .background(CinemaColors.surface.opacity(0.9))
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var exportStateIcon: String {
        if viewModel.isExporting { return "arrow.triangle.2.circlepath" }
        if viewModel.exportedVideoURL != nil { return "checkmark.circle.fill" }
        if exportPlan?.segments.isEmpty != false { return "exclamationmark.triangle.fill" }
        if exportPlan?.wasTrimmedToMaximumDuration == true { return "scissors" }
        return "film.stack"
    }

    private var exportStateTint: Color {
        if viewModel.exportedVideoURL != nil { return .green }
        if exportPlan?.segments.isEmpty != false { return .red }
        return CinemaColors.amber
    }

    private var exportStateTitle: String {
        if viewModel.isExporting { return "EXPORTING" }
        if viewModel.exportedVideoURL != nil { return "READY TO SHARE" }
        if exportPlan?.segments.isEmpty != false { return "NO EXPORTABLE CLIPS" }
        if exportPlan?.wasTrimmedToMaximumDuration == true { return "DURATION GUARDED" }
        return "LOCAL EXPORT READY"
    }

    private var exportStateMessage: String {
        if let message = viewModel.exportStatusMessage { return message }
        if exportPlan?.segments.isEmpty != false { return "Import at least one video clip with a readable duration before exporting." }
        if exportPlan?.wasTrimmedToMaximumDuration == true { return "Your short will be trimmed to the 3-minute maximum for this template." }
        return "Export combines your imported clips locally, then opens the share sheet."
    }

    private var exportPlanProgress: Double {
        guard let plan = exportPlan else { return 0 }
        return min(plan.totalDuration / VideoExportLimits.maximumDuration, 1)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startAutoAdvance()
        } else {
            stopAutoAdvance()
        }
    }

    private func startAutoAdvance() {
        let interval = session?.pacingStyle.transitionDuration ?? 2.0
        playbackTimer = Timer.scheduledTimer(withTimeInterval: max(interval + 2.0, 3.0), repeats: true) { _ in
            Task { @MainActor in
                guard let session else {
                    stopAutoAdvance()
                    return
                }
                if currentClipIndex < session.clipsInPromptOrder.count - 1 {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentClipIndex += 1
                    }
                } else {
                    stopAutoAdvance()
                }
            }
        }
    }

    private func stopAutoAdvance() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
