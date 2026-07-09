import SwiftUI

struct MyFilmsView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var appeared: Bool = false
    @State private var selectedSession: FilmSession?

    var body: some View {
        ScrollView {
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                        filmCard(session, index: index)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .background(CinemaColors.background.ignoresSafeArea())
        .overlay { FilmGrainView() }
        .navigationTitle("My Films")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MY FILMS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(CinemaColors.amber)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .task {
            await viewModel.loadSessions()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(CinemaColors.surfaceLight)
                .symbolEffect(.pulse, options: .repeating.speed(0.3))

            Text("No Films Yet")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(CinemaColors.warmWhite)

            Text("Start a new session to create\nyour first one-block cinema")
                .font(.subheadline)
                .foregroundStyle(CinemaColors.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func filmCard(_ session: FilmSession, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: session.theme.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: session.theme.icon)
                        .font(.title3)
                        .foregroundStyle(session.theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(CinemaColors.warmWhite)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(session.templateTitle ?? session.theme.displayName, systemImage: session.theme.icon)
                            .font(.caption2)
                            .foregroundStyle(session.theme.accentColor)

                        Text("\u{2022}")
                            .foregroundStyle(CinemaColors.surfaceLight)

                        Text("\(session.clips.count) clips")
                            .font(.caption2)
                            .foregroundStyle(CinemaColors.dimText)
                    }
                }

                Spacer()

                if session.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(CinemaColors.amber)
                }
            }

            HStack(spacing: 6) {
                ProgressView(value: session.progress)
                    .tint(session.theme.accentColor)

                Text("\(Int(session.progress * 100))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CinemaColors.dimText)
            }

            HStack {
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(CinemaColors.dimText.opacity(0.7))

                Spacer()

                if let completedAt = session.completedAt {
                    Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(CinemaColors.amberDim)
                }
            }
        }
        .padding(14)
        .background(CinemaColors.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.theme.accentColor.opacity(0.15), lineWidth: 1)
        )
        .contextMenu {
            Button {
                viewModel.resumeSession(session)
            } label: {
                Label("Continue", systemImage: "play.fill")
            }

            Button(role: .destructive) {
                viewModel.deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5).delay(Double(index) * 0.05), value: appeared)
    }
}
