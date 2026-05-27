import SwiftUI
import AVKit

struct AssemblyView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var selectedClip: FilmClip?
    @State private var showPreview: Bool = false

    private var session: FilmSession? { viewModel.activeSession }
    private var theme: FilmTheme { session?.theme ?? .documentary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                clipsList

                if let session, !session.clips.isEmpty {
                    limitationsSection
                    previewButton
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(CinemaColors.background.ignoresSafeArea())
        .overlay { FilmGrainView() }
        .navigationTitle("Assembly")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ASSEMBLY")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(CinemaColors.amber)
            }
        }
        .sheet(item: $selectedClip) { clip in
            ClipDetailSheet(clip: clip, viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showPreview) {
            PreviewExportView(viewModel: viewModel)
        }
    }

    private var clipsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Basic Timeline")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(CinemaColors.warmWhite)

                Text("Clips play in the original shot-prompt order. Reordering, trimming, and transitions are not available yet.")
                    .font(.caption)
                    .foregroundStyle(CinemaColors.dimText)
            }

            if session == nil {
                emptyTimelineState(
                    icon: "film.stack",
                    title: "No active film",
                    message: "Start or resume a film before assembling clips."
                )
            } else if let session, session.clips.isEmpty {
                emptyTimelineState(
                    icon: "film",
                    title: "No clips yet",
                    message: "Capture or import clips from the shot prompts, then return here to review the assembly order."
                )
            } else if let session {
                ForEach(session.prompts.sorted { $0.index < $1.index }) { prompt in
                    let promptClips = session.clipsInPromptOrder.filter { $0.promptId == prompt.id }
                    if promptClips.isEmpty {
                        timelineRow(prompt: prompt, clip: nil)
                    } else {
                        ForEach(promptClips) { clip in
                            timelineRow(prompt: prompt, clip: clip)
                        }
                    }
                }

                ForEach(session.clipsInPromptOrder.filter { clip in
                    !session.prompts.contains { $0.id == clip.promptId }
                }) { clip in
                    timelineRow(prompt: nil, clip: clip)
                }
            }
        }
    }

    private func emptyTimelineState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(CinemaColors.surfaceLight)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(CinemaColors.dimText)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(CinemaColors.dimText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func timelineRow(prompt: ShotPrompt?, clip: FilmClip?) -> some View {
        let content = HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(clip == nil ? CinemaColors.surface.opacity(0.7) : CinemaColors.surfaceLight)
                    .frame(width: 64, height: 44)

                Image(systemName: clip == nil ? "exclamationmark.triangle" : "film")
                    .font(.title3)
                    .foregroundStyle(clip == nil ? CinemaColors.dimText : theme.accentColor.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.map { "Shot \($0.index + 1)" } ?? "Unmatched clip")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(clip == nil ? CinemaColors.dimText : theme.accentColor)

                Text(prompt?.direction ?? "This clip is not linked to a current prompt.")
                    .font(.subheadline)
                    .foregroundStyle(clip == nil ? CinemaColors.dimText : CinemaColors.warmWhite)
                    .lineLimit(2)

                Text(clipStatusText(clip))
                    .font(.caption)
                    .foregroundStyle(CinemaColors.dimText)
            }

            Spacer()

            if clip != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(CinemaColors.surfaceLight)
            }
        }
        .padding(12)
        .background(CinemaColors.surface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(clip == nil ? CinemaColors.surfaceLight.opacity(0.4) : .clear, lineWidth: 1)
        )

        if let clip {
            Button {
                selectedClip = clip
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func clipStatusText(_ clip: FilmClip?) -> String {
        guard let clip else { return "Missing clip — this shot will be skipped." }
        return clip.duration > 0 ? String(format: "Clip ready · %.1fs", clip.duration) : "Clip ready · imported duration unavailable"
    }

    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What this assembly can do")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            capabilityRow(icon: "checkmark.circle.fill", text: "Plays captured clips in shot-prompt order")
            capabilityRow(icon: "checkmark.circle.fill", text: "Skips prompts that do not have clips yet")
            capabilityRow(icon: "lock.fill", text: "Trim, reorder, transitions, title cards, and soundtrack controls are not built yet")
        }
        .padding(14)
        .background(CinemaColors.surface.opacity(0.8))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func capabilityRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(icon == "lock.fill" ? CinemaColors.dimText : CinemaColors.amber)
                .padding(.top, 2)

            Text(text)
                .font(.caption)
                .foregroundStyle(CinemaColors.dimText)

            Spacer(minLength: 0)
        }
    }

    private var previewButton: some View {
        Button {
            showPreview = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Preview & Export")
                    .font(.system(.headline, design: .serif))
            }
            .foregroundStyle(CinemaColors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(CinemaColors.amber)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: CinemaColors.amberGlow, radius: 16)
        }
        .padding(.top, 8)
    }
}

struct ClipDetailSheet: View {
    let clip: FilmClip
    @Bindable var viewModel: FilmSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(clip: FilmClip, viewModel: FilmSessionViewModel) {
        self.clip = clip
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if clip.duration > 0 {
                        LabeledContent("Duration", value: String(format: "%.1f seconds", clip.duration))
                    }
                    LabeledContent("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Editing") {
                    Text("Trim, reorder, transitions, title cards, and soundtrack controls are not available in this MVP slice.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Remove Clip", role: .destructive) {
                        viewModel.removeClip(clip)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
