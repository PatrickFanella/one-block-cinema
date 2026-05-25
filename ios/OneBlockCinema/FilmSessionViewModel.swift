import SwiftUI
import AVFoundation
import PhotosUI

@Observable
@MainActor
class FilmSessionViewModel {
    var sessions: [FilmSession] = []
    var activeSession: FilmSession?
    var currentPromptIndex: Int = 0
    var isRecording: Bool = false
    var isExporting: Bool = false
    var exportedVideoURL: URL?
    var errorMessage: String?
    var showError: Bool = false
    var showCamera: Bool = false
    var showPhotoPicker: Bool = false
    var showExportShare: Bool = false

    private let storage = SessionStorage()
    private let exportService = VideoExportService()

    var currentPrompt: ShotPrompt? {
        guard let session = activeSession,
              currentPromptIndex < session.prompts.count else { return nil }
        return session.prompts[currentPromptIndex]
    }

    var currentPromptClip: FilmClip? {
        guard let promptId = currentPrompt?.id else { return nil }
        return activeSession?.clip(forPromptId: promptId)
    }

    var hasNextPrompt: Bool {
        guard let session = activeSession else { return false }
        return currentPromptIndex < session.prompts.count - 1
    }

    var hasPreviousPrompt: Bool {
        currentPromptIndex > 0
    }

    func loadSessions() async {
        sessions = await storage.loadSessions()
    }

    func startNewSession(theme: FilmTheme) {
        let prompts = PromptGenerator.generatePrompts(for: theme)
        let session = FilmSession(
            theme: theme,
            prompts: prompts,
            title: "\(theme.displayName) — \(Date().formatted(date: .abbreviated, time: .shortened))"
        )
        activeSession = session
        currentPromptIndex = 0
    }

    func resumeSession(_ session: FilmSession) {
        activeSession = session
        let firstIncomplete = session.prompts.firstIndex(where: { !$0.isCompleted }) ?? 0
        currentPromptIndex = firstIncomplete
    }

    func nextPrompt() {
        guard hasNextPrompt else { return }
        currentPromptIndex += 1
    }

    func previousPrompt() {
        guard hasPreviousPrompt else { return }
        currentPromptIndex -= 1
    }

    func goToPrompt(at index: Int) {
        guard let session = activeSession,
              index >= 0 && index < session.prompts.count else { return }
        currentPromptIndex = index
    }

    func markCurrentPromptCompleted() {
        guard activeSession != nil else { return }
        activeSession?.prompts[currentPromptIndex].isCompleted = true
        saveCurrentSession()
    }

    @discardableResult
    func addClip(from url: URL, forPromptId: UUID) throws -> FilmClip {
        guard var session = activeSession else {
            throw ClipImportError.noActiveSession
        }

        let clip = FilmClip(
            promptId: forPromptId,
            fileURL: url,
            duration: videoDuration(for: url)
        )

        guard session.attachClip(clip) else {
            throw ClipImportError.promptNotFound
        }

        activeSession = session
        saveCurrentSession()
        return clip
    }

    func removeClip(_ clip: FilmClip) {
        activeSession?.removeClip(clip)
        saveCurrentSession()
    }

    func reorderClips(from source: IndexSet, to destination: Int) {
        activeSession?.clips.move(fromOffsets: source, toOffset: destination)
        saveCurrentSession()
    }

    func toggleClipTitle(_ clip: FilmClip) {
        guard let index = activeSession?.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        activeSession?.clips[index].showTitle.toggle()
        saveCurrentSession()
    }

    func updateClipTitle(_ clip: FilmClip, title: String) {
        guard let index = activeSession?.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        activeSession?.clips[index].titleText = title
        saveCurrentSession()
    }

    func setPacingStyle(_ style: PacingStyle) {
        activeSession?.pacingStyle = style
        saveCurrentSession()
    }

    func setEditStyle(_ style: EditStyle) {
        activeSession?.editStyle = style
        saveCurrentSession()
    }

    func toggleAmbientSoundtrack() {
        activeSession?.useAmbientSoundtrack.toggle()
        saveCurrentSession()
    }

    func exportVideo() async {
        guard let session = activeSession, !session.clips.isEmpty else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await exportService.exportAssembledVideo(
                clips: session.clips,
                pacingStyle: session.pacingStyle,
                editStyle: session.editStyle
            )
            exportedVideoURL = url
            showExportShare = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func completeSession() {
        activeSession?.completedAt = Date()
        saveCurrentSession()
        if let session = activeSession {
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.insert(session, at: 0)
            }
            Task {
                await storage.saveSessions(sessions)
            }
        }
    }

    func deleteSession(_ session: FilmSession) {
        sessions.removeAll { $0.id == session.id }
        Task {
            await storage.saveSessions(sessions)
        }
    }

    func saveCurrentSession() {
        guard let session = activeSession else { return }
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        Task {
            await storage.saveSessions(sessions)
        }
    }

    private func videoDuration(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isNaN ? 0 : duration
    }
}

nonisolated enum ClipImportError: LocalizedError, Sendable {
    case noActiveSession
    case promptNotFound
    case noVideoSelected

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "Start or resume a film before importing clips."
        case .promptNotFound:
            return "This clip could not be matched to the selected shot prompt."
        case .noVideoSelected:
            return "No video was selected. Choose a clip from your library to attach it to this shot."
        }
    }
}
