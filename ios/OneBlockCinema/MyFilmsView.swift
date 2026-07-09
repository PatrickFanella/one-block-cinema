import SwiftUI

struct MyFilmsView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var appeared: Bool = false
    @State private var selectedSessionID: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.storageHealth.needsAttention || viewModel.storageCleanupMessage != nil {
                    storageRecoveryCard
                }

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
        .navigationDestination(item: $selectedSessionID) { _ in
            ShotSequenceView(viewModel: viewModel)
        }
    }

    private var storageRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Draft Recovery", systemImage: "externaldrive.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(CinemaColors.warmWhite)

            if viewModel.storageHealth.missingClipCount > 0 {
                Text(missingMediaSummary)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if viewModel.storageHealth.recoveryIssueCount > 0 {
                Text(recoveryIssueSummary)
                    .font(.caption)
                    .foregroundStyle(CinemaColors.dimText)
            }

            if viewModel.storageHealth.reclaimableFileCount > 0 {
                Text(reclaimableMediaSummary)
                    .font(.caption)
                    .foregroundStyle(CinemaColors.dimText)

                Button {
                    Task { await viewModel.cleanupUnusedMedia() }
                } label: {
                    if viewModel.isCleaningStorage {
                        ProgressView()
                    } else {
                        Label("Clean Up Unused Media", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .tint(CinemaColors.amber)
                .disabled(viewModel.isCleaningStorage)
            }

            if let message = viewModel.storageCleanupMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(CinemaColors.amber)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CinemaColors.surface)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }

    private var missingMediaSummary: String {
        let count = viewModel.storageHealth.missingClipCount
        let verb = count == 1 ? "is" : "are"
        return "\(count) source clip\(count == 1 ? "" : "s") \(verb) missing. "
            + "Open a marked film to record or import a replacement."
    }

    private var recoveryIssueSummary: String {
        let count = viewModel.storageHealth.recoveryIssueCount
        let verb = count == 1 ? "was" : "were"
        return "\(count) earlier draft record\(count == 1 ? "" : "s") \(verb) preserved for support recovery "
            + "because it could not be read."
    }

    private var reclaimableMediaSummary: String {
        let count = viewModel.storageHealth.reclaimableFileCount
        let size = formattedBytes(viewModel.storageHealth.reclaimableBytes)
        return "\(count) unused file\(count == 1 ? "" : "s") can be safely removed (\(size))."
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
        Button {
            open(session)
        } label: {
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

                if session.missingClipCount > 0 {
                    Label("\(session.missingClipCount) missing clip\(session.missingClipCount == 1 ? "" : "s") — tap to repair", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(CinemaColors.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.theme.accentColor.opacity(0.15), lineWidth: 1)
        )
        .contextMenu {
            Button {
                open(session)
            } label: {
                Label(session.missingClipCount > 0 ? "Repair Missing Clips" : "Continue", systemImage: session.missingClipCount > 0 ? "wrench.and.screwdriver" : "play.fill")
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

    private func open(_ session: FilmSession) {
        viewModel.resumeSession(session)
        selectedSessionID = session.id
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
