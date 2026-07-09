import SwiftUI

struct ShotSequenceView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var showCapture: Bool = false
    @State private var cardBounce: Int = 0

    private var session: FilmSession? {
        viewModel.activeSession
    }

    private var theme: FilmTheme {
        session?.theme ?? .documentary
    }

    var body: some View {
        ZStack {
            CinemaColors.background.ignoresSafeArea()
            FilmGrainView()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 8)

                ScrollView {
                    if let prompt = viewModel.currentPrompt {
                        promptCard(prompt)
                            .id(prompt.id)
                            .transition(promptTransition)
                            .padding(.vertical, 16)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

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
                    .accessibilityLabel("Open Assembly")
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
                    Button {
                        performNavigation {
                            viewModel.goToPrompt(at: index)
                        }
                    } label: {
                        Circle()
                            .fill(dotColor(for: prompt, at: index))
                            .frame(
                                width: index == viewModel.currentPromptIndex ? 10 : 6,
                                height: index == viewModel.currentPromptIndex ? 10 : 6
                            )
                            .shadow(
                                color: index == viewModel.currentPromptIndex
                                    ? theme.accentColor.opacity(0.6)
                                    : .clear,
                                radius: 4
                            )
                            .frame(minWidth: 36, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.3),
                        value: viewModel.currentPromptIndex
                    )
                    .accessibilityLabel("Shot \(index + 1)")
                    .accessibilityValue(dotAccessibilityValue(for: prompt, at: index))
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func dotColor(for prompt: ShotPrompt, at index: Int) -> Color {
        if prompt.isCompleted {
            CinemaColors.amber
        } else if index == viewModel.currentPromptIndex {
            theme.accentColor
        } else {
            CinemaColors.surfaceLight
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

                promptIcon(prompt)
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
        .accessibilityIdentifier("shot.\(prompt.index + 1)")
        .accessibilityElement(children: .combine)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = reduceMotion ? 0 : value.translation.width * 0.4
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width < -threshold, viewModel.hasNextPrompt {
                        performNavigation {
                            viewModel.nextPrompt()
                            cardBounce += 1
                        }
                    } else if value.translation.width > threshold, viewModel.hasPreviousPrompt {
                        performNavigation {
                            viewModel.previousPrompt()
                            cardBounce += 1
                        }
                    }
                    performNavigation { dragOffset = 0 }
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
                performNavigation {
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
            .accessibilityLabel("Previous shot")

            Button {
                showCapture = true
            } label: {
                let needsRepair = viewModel.currentPromptClip?.mediaStatus == .missing
                HStack(spacing: 8) {
                    captureActionIcon(needsRepair: needsRepair)
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
                performNavigation {
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
            .accessibilityLabel("Next shot")
        }
    }

    private var promptTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    @ViewBuilder
    private func promptIcon(_ prompt: ShotPrompt) -> some View {
        let icon = Image(systemName: prompt.icon)
            .font(.system(size: 40))
            .foregroundStyle(theme.accentColor)
            .accessibilityHidden(true)
        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.bounce, value: cardBounce)
        }
    }

    @ViewBuilder
    private func captureActionIcon(needsRepair: Bool) -> some View {
        let name = needsRepair
            ? "wrench.and.screwdriver.fill"
            : viewModel.currentPrompt?.isCompleted == true
            ? "arrow.triangle.2.circlepath"
            : "camera.fill"
        let icon = Image(systemName: name)
        if reduceMotion {
            icon
        } else {
            icon.contentTransition(.symbolEffect(.replace))
        }
    }

    private func performNavigation(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.spring(response: 0.4)) {
                updates()
            }
        }
    }

    private func dotAccessibilityValue(for prompt: ShotPrompt, at index: Int) -> String {
        if index == viewModel.currentPromptIndex {
            return prompt.isCompleted ? "current, complete" : "current, incomplete"
        }
        return prompt.isCompleted ? "complete" : "incomplete"
    }
}
