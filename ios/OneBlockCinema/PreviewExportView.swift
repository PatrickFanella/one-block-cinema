import AVKit
import SwiftUI

struct PreviewExportView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var player = AVPlayer()
    @State private var isPreparingPreview = false
    @State private var previewError: String?
    @State private var showShareSheet = false

    private var session: FilmSession? { viewModel.activeSession }
    private var exportPlan: RenderPlan? {
        guard let session else { return nil }
        return VideoExportLimits.plan(for: session)
    }

    private var previewIdentity: String {
        guard let session else { return "no-session" }
        let clips = session.clipsInEditOrder.map {
            "\($0.id.uuidString):\($0.duration):\($0.effectiveTrimStart):\($0.effectiveTrimEnd):\($0.showTitle):\($0.titleText):\($0.volume):\($0.mediaStatus.rawValue)"
        }.joined(separator: "|")
        return "\(session.id.uuidString):\(session.aspectRatio?.rawValue ?? "16:9"):\(session.pacingStyle.rawValue):\(session.editStyle.rawValue):\(clips)"
    }

    var body: some View {
        ZStack {
            CinemaColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                playerSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                controlsOverlay
            }
        }
        .overlay { FilmGrainView().allowsHitTesting(false) }
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
        .task(id: previewIdentity) {
            await preparePreview()
        }
        .onDisappear {
            player.pause()
        }
    }

    private var playerSurface: some View {
        ZStack {
            Color.black

            if let plan = exportPlan, !plan.segments.isEmpty {
                VideoPlayer(player: player)
                    .aspectRatio(plan.outputDimensions.size, contentMode: .fit)
                    .accessibilityLabel("Assembled film preview")

                if isPreparingPreview {
                    preparationOverlay(icon: nil, message: "Building preview…")
                } else if let previewError {
                    preparationOverlay(icon: "exclamationmark.triangle.fill", message: previewError)
                }
            } else {
                preparationOverlay(icon: "film.stack", message: "No exportable clips to preview")
            }
        }
    }

    private func preparationOverlay(icon: String?, message: String) -> some View {
        VStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(CinemaColors.amber)
            } else {
                ProgressView()
                    .tint(CinemaColors.amber)
            }
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(CinemaColors.warmWhite)
                .padding(.horizontal, 24)
        }
        .padding(20)
        .background(.black.opacity(0.75))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var controlsOverlay: some View {
        VStack(spacing: 14) {
            outputSummary
            exportStateCard

            if viewModel.isExporting {
                Button(role: .cancel) {
                    viewModel.cancelExport()
                } label: {
                    Label("Cancel Export", systemImage: "xmark.circle")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.bordered)
                .tint(CinemaColors.warmWhite)
                .padding(.horizontal)
            } else {
                Button {
                    player.pause()
                    Task { await viewModel.exportVideo() }
                } label: {
                    Label("Export & Share", systemImage: "square.and.arrow.up")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(CinemaColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CinemaColors.amber)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(exportPlan?.segments.isEmpty != false || isPreparingPreview)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [.clear, CinemaColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var outputSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.inset.filled")
                .foregroundStyle(CinemaColors.amber)
            if let plan = exportPlan {
                Text("\(plan.outputDimensions.width) × \(plan.outputDimensions.height) · 30 FPS · MP4")
                    .font(.caption2.monospaced())
                    .foregroundStyle(CinemaColors.dimText)
            }
            Spacer()
        }
        .padding(.horizontal)
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
        if exportPlan?.segments.isEmpty != false {
            return "Import at least one available video clip with a readable duration before exporting."
        }
        if exportPlan?.wasTrimmedToMaximumDuration == true {
            return "Your short will be trimmed to the 3-minute maximum."
        }
        return "Preview and export use the same orientation-normalized render plan."
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

    private func preparePreview() async {
        player.pause()
        player.replaceCurrentItem(with: nil)
        previewError = nil

        guard let plan = exportPlan, !plan.segments.isEmpty else { return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }

        do {
            let prepared = try await RenderCompositionBuilder.build(plan: plan)
            try Task.checkCancellation()
            player.replaceCurrentItem(with: prepared.makePlayerItem())
        } catch is CancellationError {
            return
        } catch {
            previewError = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
