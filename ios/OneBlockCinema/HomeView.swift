import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var selectedTemplate: FilmTemplate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection

                if let inProgress = viewModel.activeSession, inProgress.completedAt == nil {
                    continueSessionCard(inProgress)
                }

                themeSectionHeader
                themeCards
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(CinemaColors.background.ignoresSafeArea())
        .overlay { FilmGrainView() }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ONE-BLOCK")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .tracking(4)
                .foregroundStyle(CinemaColors.amberDim)

            Text("Cinema")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(CinemaColors.warmWhite)
                .accessibilityIdentifier("home.title")

            Text("Turn your surroundings into a short film")
                .font(.subheadline)
                .foregroundStyle(CinemaColors.dimText)
        }
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: reduceMotion || appeared ? 0 : 10)
    }

    private func continueSessionCard(_ session: FilmSession) -> some View {
        Button {
            viewModel.resumeSession(session)
            selectedTemplate = session.templateId.flatMap(TemplateCatalog.template(id:))
                ?? TemplateCatalog.template(for: session.theme)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(CinemaColors.surfaceLight, lineWidth: 3)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: session.progress)
                        .stroke(session.theme.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: session.theme.icon)
                        .font(.title3)
                        .foregroundStyle(session.theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Session")
                        .font(.headline)
                        .foregroundStyle(CinemaColors.warmWhite)
                    Text("\(session.theme.displayName) \u{2022} \(session.completedPromptCount)/\(session.prompts.count) shots")
                        .font(.caption)
                        .foregroundStyle(CinemaColors.dimText)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(CinemaColors.amber)
            }
            .padding(16)
            .background(CinemaColors.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(session.theme.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: reduceMotion || appeared ? 0 : 15)
        .animation(reduceMotion ? nil : .spring(response: 0.5).delay(0.1), value: appeared)
        .accessibilityLabel("Continue \(session.title)")
        .accessibilityValue("\(session.completedPromptCount) of \(session.prompts.count) shots complete")
        .navigationDestination(item: $selectedTemplate) { _ in
            ShotSequenceView(viewModel: viewModel)
        }
    }

    private var themeSectionHeader: some View {
        HStack {
            Text("Choose Your Story")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(CinemaColors.warmWhite)
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.2), value: appeared)
    }

    private var themeCards: some View {
        VStack(spacing: 14) {
            ForEach(Array(TemplateCatalog.launchTemplates.enumerated()), id: \.element.id) { index, template in
                TemplateCard(template: template) {
                    viewModel.startNewSession(template: template)
                    selectedTemplate = template
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: reduceMotion || appeared ? 0 : 20)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5).delay(0.15 + Double(index) * 0.06),
                    value: appeared
                )
            }
        }
    }
}

struct TemplateCard: View {
    let template: FilmTemplate
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: FilmTheme { template.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.accentColor.opacity(0.4), lineWidth: 1)
                        )

                    templateIcon
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(CinemaColors.warmWhite)
                    Text(template.subtitle)
                        .font(.caption)
                        .foregroundStyle(CinemaColors.dimText)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            templateMetadata
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            templateMetadata
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.accentColor.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(CinemaColors.amberDim)
            }
            .padding(14)
            .background(CinemaColors.surface)
            .clipShape(.rect(cornerRadius: 16))
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: template.id)
        .accessibilityIdentifier("template.\(template.id)")
        .accessibilityLabel("\(template.displayName). \(template.subtitle)")
        .accessibilityValue(
            "\(template.shotCount) shots, \(template.durationTarget.targetSeconds) seconds, \(template.aspectRatio.rawValue)"
        )
    }

    @ViewBuilder
    private var templateIcon: some View {
        let icon = Image(systemName: theme.icon)
            .font(.title2)
            .foregroundStyle(theme.accentColor)
        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.pulse, options: .repeating.speed(0.3))
        }
    }

    @ViewBuilder
    private var templateMetadata: some View {
        Label(template.aspectRatio.rawValue, systemImage: "aspectratio")
        Label("\(template.durationTarget.targetSeconds)s", systemImage: "timer")
        Label("\(template.shotCount) shots", systemImage: "film.stack")
    }
}
