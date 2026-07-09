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
                    lookSection
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

                Text("Use the arrow controls to set the playback order. Open a clip to choose its in and out points.")
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
                let orderedClips = session.clipsInEditOrder
                ForEach(Array(orderedClips.enumerated()), id: \.element.id) { position, clip in
                    timelineRow(
                        prompt: session.prompts.first { $0.id == clip.promptId },
                        clip: clip,
                        position: position,
                        clipCount: orderedClips.count
                    )
                }

                ForEach(session.prompts.sorted { $0.index < $1.index }.filter { prompt in
                    !session.clips.contains { $0.promptId == prompt.id }
                }) { prompt in
                    timelineRow(prompt: prompt, clip: nil, position: nil, clipCount: orderedClips.count)
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
    private func timelineRow(prompt: ShotPrompt?, clip: FilmClip?, position: Int?, clipCount: Int) -> some View {
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

            Image(systemName: clip == nil ? "circle.dashed" : "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(CinemaColors.surfaceLight)
        }
        .padding(12)
        .background(CinemaColors.surface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(clip == nil ? CinemaColors.surfaceLight.opacity(0.4) : .clear, lineWidth: 1)
        )

        if let clip {
            HStack(spacing: 8) {
                Button {
                    selectedClip = clip
                } label: {
                    content
                }
                .buttonStyle(.plain)

                if let position {
                    VStack(spacing: 4) {
                        Button {
                            viewModel.moveClip(clip, by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .frame(width: 36, height: 32)
                        }
                        .disabled(position == 0)
                        .accessibilityLabel("Move clip earlier")

                        Button {
                            viewModel.moveClip(clip, by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .frame(width: 36, height: 32)
                        }
                        .disabled(position == clipCount - 1)
                        .accessibilityLabel("Move clip later")
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.accentColor)
                }
            }
        } else {
            content
        }
    }

    private func clipStatusText(_ clip: FilmClip?) -> String {
        guard let clip else { return "Missing clip — this shot will be skipped." }
        return clip.duration > 0
            ? String(format: "Using %.1fs of %.1fs", clip.trimmedDuration, clip.duration)
            : "Clip ready · imported duration unavailable"
    }

    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What this assembly can do")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            capabilityRow(icon: "checkmark.circle.fill", text: "Uses your saved clip order and non-destructive trim points")
            capabilityRow(icon: "checkmark.circle.fill", text: "Renders clip title overlays, per-clip audio levels, and the selected look")
            capabilityRow(icon: "checkmark.circle.fill", text: "Skips prompts that do not have clips yet")
            capabilityRow(icon: "lock.fill", text: "Transitions, standalone intertitle cards, voiceover, and soundtrack beds are not built yet")
        }
        .padding(14)
        .background(CinemaColors.surface.opacity(0.8))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Film Look")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            Picker(
                "Film Look",
                selection: Binding(
                    get: { viewModel.activeSession?.editStyle == .silentFilm ? EditStyle.silentFilm : .standard },
                    set: { viewModel.setEditStyle($0) }
                )
            ) {
                Text("Standard").tag(EditStyle.standard)
                Text("Silent Film").tag(EditStyle.silentFilm)
            }
            .pickerStyle(.segmented)

            Text(viewModel.activeSession?.editStyle == .silentFilm
                ? "Adds a warm archival tint and mutes source audio in preview and export."
                : "Keeps natural color and uses each clip's saved audio level.")
                .font(.caption)
                .foregroundStyle(CinemaColors.dimText)
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
    @State private var trimStart: TimeInterval
    @State private var trimEnd: TimeInterval
    @State private var showTitle: Bool
    @State private var titleText: String
    @State private var volume: Double

    init(clip: FilmClip, viewModel: FilmSessionViewModel) {
        self.clip = clip
        self.viewModel = viewModel
        _trimStart = State(initialValue: clip.effectiveTrimStart)
        _trimEnd = State(initialValue: clip.effectiveTrimEnd)
        _showTitle = State(initialValue: clip.showTitle)
        _titleText = State(initialValue: clip.titleText)
        _volume = State(initialValue: min(max(clip.volume, 0), 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if clip.duration > 0 {
                        LabeledContent("Source duration", value: formattedTime(clip.duration))
                        LabeledContent("Selected duration", value: formattedTime(max(0, trimEnd - trimStart)))
                    }
                    LabeledContent("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Editing") {
                    if clip.duration >= 0.2 {
                        VStack(alignment: .leading) {
                            LabeledContent("Starts at", value: formattedTime(trimStart))
                            Slider(
                                value: $trimStart,
                                in: 0...max(0, trimEnd - 0.1)
                            )
                            .accessibilityLabel("Clip start time")
                        }

                        VStack(alignment: .leading) {
                            LabeledContent("Ends at", value: formattedTime(trimEnd))
                            Slider(
                                value: $trimEnd,
                                in: min(clip.duration, trimStart + 0.1)...clip.duration
                            )
                            .accessibilityLabel("Clip end time")
                        }

                        Button("Use Full Clip") {
                            trimStart = 0
                            trimEnd = clip.duration
                        }
                    } else {
                        Text("This clip is too short to trim safely.")
                            .foregroundStyle(.secondary)
                    }

                    Text("Trimming is non-destructive; the original clip stays unchanged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Title") {
                    Toggle("Show title over clip", isOn: $showTitle)
                    TextField("Title text", text: $titleText)
                        .disabled(!showTitle)
                    Text("Titles appear briefly at the beginning of this clip in preview and export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Clip audio") {
                    LabeledContent("Volume", value: "\(Int(volume * 100))%")
                    Slider(value: $volume, in: 0...1)
                        .accessibilityLabel("Clip volume")
                    Text("This changes the mix without modifying the source file.")
                        .font(.caption)
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
                    Button("Save") {
                        viewModel.updateClipEdits(
                            id: clip.id,
                            start: trimStart,
                            end: trimEnd,
                            showTitle: showTitle,
                            title: titleText,
                            volume: volume
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        String(format: "%.1f seconds", time)
    }
}
