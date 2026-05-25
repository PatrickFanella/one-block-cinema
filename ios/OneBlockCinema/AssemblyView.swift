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
                    pacingSection
                    editStyleSection
                    ambientToggle

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
            Text("Your Clips")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            if let session, session.clips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 36))
                        .foregroundStyle(CinemaColors.surfaceLight)
                    Text("No clips yet")
                        .font(.subheadline)
                        .foregroundStyle(CinemaColors.dimText)
                    Text("Go back and capture some shots")
                        .font(.caption)
                        .foregroundStyle(CinemaColors.dimText.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let session {
                ForEach(Array(session.clips.enumerated()), id: \.element.id) { index, clip in
                    clipRow(clip, index: index)
                }
            }
        }
    }

    private func clipRow(_ clip: FilmClip, index: Int) -> some View {
        Button {
            selectedClip = clip
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CinemaColors.surfaceLight)
                        .frame(width: 64, height: 44)

                    Image(systemName: "film")
                        .font(.title3)
                        .foregroundStyle(theme.accentColor.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let prompt = session?.prompts.first(where: { $0.id == clip.promptId }) {
                        Text("Shot \(prompt.index + 1)")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(theme.accentColor)
                    }

                    Text(clip.duration > 0 ? String(format: "%.1fs", clip.duration) : "Imported clip")
                        .font(.caption)
                        .foregroundStyle(CinemaColors.dimText)
                }

                Spacer()

                if clip.showTitle {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(CinemaColors.amberDim)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(CinemaColors.surfaceLight)
            }
            .padding(12)
            .background(CinemaColors.surface)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var pacingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pacing")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            HStack(spacing: 10) {
                ForEach(PacingStyle.allCases) { style in
                    pacingButton(style)
                }
            }
        }
    }

    private func pacingButton(_ style: PacingStyle) -> some View {
        let isSelected = session?.pacingStyle == style
        return Button {
            viewModel.setPacingStyle(style)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? CinemaColors.amber : CinemaColors.dimText)
                    .symbolEffect(.bounce, value: isSelected)

                Text(style.displayName)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(isSelected ? CinemaColors.warmWhite : CinemaColors.dimText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? CinemaColors.surface : CinemaColors.surface.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? CinemaColors.amber.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var editStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(CinemaColors.warmWhite)

            ForEach(EditStyle.allCases) { style in
                editStyleRow(style)
            }
        }
    }

    private func editStyleRow(_ style: EditStyle) -> some View {
        let isSelected = session?.editStyle == style
        return Button {
            viewModel.setEditStyle(style)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? CinemaColors.amber : CinemaColors.dimText)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .foregroundStyle(isSelected ? CinemaColors.warmWhite : CinemaColors.dimText)
                    Text(style.description)
                        .font(.caption2)
                        .foregroundStyle(CinemaColors.dimText.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CinemaColors.amber)
                }
            }
            .padding(12)
            .background(isSelected ? CinemaColors.surface : CinemaColors.surface.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? CinemaColors.amber.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
    }

    private var ambientToggle: some View {
        Button {
            viewModel.toggleAmbientSoundtrack()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title3)
                    .foregroundStyle(session?.useAmbientSoundtrack == true ? CinemaColors.amber : CinemaColors.dimText)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambient Soundtrack")
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .foregroundStyle(CinemaColors.warmWhite)
                    Text("Use captured audio as background sound")
                        .font(.caption2)
                        .foregroundStyle(CinemaColors.dimText)
                }

                Spacer()

                Image(systemName: session?.useAmbientSoundtrack == true ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(session?.useAmbientSoundtrack == true ? CinemaColors.amber : CinemaColors.surfaceLight)
            }
            .padding(12)
            .background(CinemaColors.surface)
            .clipShape(.rect(cornerRadius: 12))
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
    @State private var titleText: String

    init(clip: FilmClip, viewModel: FilmSessionViewModel) {
        self.clip = clip
        self.viewModel = viewModel
        _titleText = State(initialValue: clip.titleText)
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

                Section("Title Card") {
                    Toggle("Show Title", isOn: Binding(
                        get: { clip.showTitle },
                        set: { viewModel.toggleClipTitle(clip); _ = $0 }
                    ))

                    if clip.showTitle {
                        TextField("Title text", text: $titleText)
                            .onChange(of: titleText) { _, newValue in
                                viewModel.updateClipTitle(clip, title: newValue)
                            }
                    }
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
