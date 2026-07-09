import SwiftUI

struct ShotSequenceView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var showCapture: Bool = false
    @State private var cardBounce: Int = 0

    private var session: FilmSession? { viewModel.activeSession }
    private var theme: FilmTheme { session?.theme ?? .documentary }

    var body: some View {
        ZStack {
            CinemaColors.background.ignoresSafeArea()
            FilmGrainView()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 8)

                Spacer()

                if let prompt = viewModel.currentPrompt {
                    promptCard(prompt)
                        .id(prompt.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer()

                bottomControls
                    .padding(.bottom, 16)
            }
            .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text((session?.templateTitle ?? theme.displayName).uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(theme.accentColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let session, !session.clips.isEmpty {
                    NavigationLink(value: "assembly") {
                        Image(systemName: "film.stack")
                            .foregroundStyle(CinemaColors.amber)
                    }
                }
            }
        }
        .navigationDestination(for: String.self) { destination in
            if destination == "assembly" {
                AssemblyView(viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView(viewModel: viewModel)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            if let session {
                ForEach(Array(session.prompts.enumerated()), id: \.element.id) { index, prompt in
                    Circle()
                        .fill(dotColor(for: prompt, at: index))
                        .frame(width: index == viewModel.currentPromptIndex ? 10 : 6,
                               height: index == viewModel.currentPromptIndex ? 10 : 6)
                        .shadow(color: index == viewModel.currentPromptIndex ? theme.accentColor.opacity(0.6) : .clear, radius: 4)
                        .animation(.spring(response: 0.3), value: viewModel.currentPromptIndex)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4)) {
                                viewModel.goToPrompt(at: index)
                            }
                        }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func dotColor(for prompt: ShotPrompt, at index: Int) -> Color {
        if prompt.isCompleted {
            return CinemaColors.amber
        } else if index == viewModel.currentPromptIndex {
            return theme.accentColor
        } else {
            return CinemaColors.surfaceLight
        }
    }

    private func promptCard(_ prompt: ShotPrompt) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.accentColor.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: prompt.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(theme.accentColor)
                    .symbolEffect(.bounce, value: cardBounce)
            }

            VStack(spacing: 12) {
                Text("SHOT \(prompt.index + 1)")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(theme.accentColor.opacity(0.7))

                Text(prompt.direction)
                    .font(.system(.title3, design: .serif, weight: .medium))
                    .foregroundStyle(CinemaColors.warmWhite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(prompt.hint)
                    .font(.subheadline)
                    .foregroundStyle(CinemaColors.dimText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if session?.clip(forPromptId: prompt.id)?.mediaStatus == .missing {
                Label("Clip missing — capture or import a replacement", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
            } else if prompt.isCompleted {
                Label(clipStatusText(for: prompt), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(CinemaColors.amber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CinemaColors.amber.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(CinemaColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.accentColor.opacity(0.15), lineWidth: 1)
                )
        )
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width * 0.4
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width < -threshold && viewModel.hasNextPrompt {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.nextPrompt()
                            cardBounce += 1
                        }
                    } else if value.translation.width > threshold && viewModel.hasPreviousPrompt {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.previousPrompt()
                            cardBounce += 1
                        }
                    }
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = 0
                    }
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.currentPromptIndex)
    }

    private func clipStatusText(for prompt: ShotPrompt) -> String {
        if session?.clip(forPromptId: prompt.id) != nil {
            return "Clip attached"
        }

        return "Captured"
    }

    private var bottomControls: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.previousPrompt()
                    cardBounce += 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(viewModel.hasPreviousPrompt ? CinemaColors.warmWhite : CinemaColors.surfaceLight)
                    .frame(width: 48, height: 48)
                    .background(CinemaColors.surface)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.hasPreviousPrompt)

            Button {
                showCapture = true
            } label: {
                let needsRepair = viewModel.currentPromptClip?.mediaStatus == .missing
                HStack(spacing: 8) {
                    Image(systemName: needsRepair ? "wrench.and.screwdriver.fill" : viewModel.currentPrompt?.isCompleted == true ? "arrow.triangle.2.circlepath" : "camera.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(needsRepair ? "Repair Clip" : viewModel.currentPrompt?.isCompleted == true ? "Reshoot" : "Capture")
                        .font(.system(.headline, design: .serif))
                }
                .foregroundStyle(CinemaColors.background)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(CinemaColors.amber)
                .clipShape(Capsule())
                .shadow(color: CinemaColors.amberGlow, radius: 12)
            }

            Button {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.nextPrompt()
                    cardBounce += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundStyle(viewModel.hasNextPrompt ? CinemaColors.warmWhite : CinemaColors.surfaceLight)
                    .frame(width: 48, height: 48)
                    .background(CinemaColors.surface)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.hasNextPrompt)
        }
    }
}
