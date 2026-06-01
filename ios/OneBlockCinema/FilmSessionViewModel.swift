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
    var exportProgress: Double = 0
    var exportStatusMessage: String?
    var exportedVideoURL: URL?
    var errorMessage: String?
    var showError: Bool = false
    var showCamera: Bool = false
    var showPhotoPicker: Bool = false
    var showExportShare: Bool = false

    private let storage: SessionStorage
    private let exportService = VideoExportService()
    private var pendingPersistenceTask: Task<Void, Never>?
    private var activeExportID: UUID?

    init(storage: SessionStorage = SessionStorage()) {
        self.storage = storage
    }

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
        do {
            sessions = try await storage.loadSessions()
        } catch {
            errorMessage = "Failed to load drafts: \(error.localizedDescription)"
            showError = true
            sessions = []
        }
    }

    func startNewSession(theme: FilmTheme) {
        createDraft(theme: theme)
    }

    @discardableResult
    func createDraft(theme: FilmTheme) -> FilmSession {
        let template = TemplateCatalog.template(for: theme)
        let prompts = PromptGenerator.generatePrompts(for: template)
        let session = FilmSession(
            theme: theme,
            templateId: template.id,
            aspectRatio: template.aspectRatio,
            durationTarget: template.durationTarget,
            assemblyGuidance: template.assemblyGuidance,
            prompts: prompts,
            pacingStyle: template.assemblyGuidance.pacingStyle,
            editStyle: template.assemblyGuidance.editStyle,
            useAmbientSoundtrack: template.assemblyGuidance.useAmbientSoundtrack,
            title: "\(template.displayName) — \(Date().formatted(date: .abbreviated, time: .shortened))"
        )
        activeSession = session
        currentPromptIndex = 0
        resetExportState()
        upsertSession(session)
        persistSessions()
        return session
    }

    func resumeSession(_ session: FilmSession) {
        activeSession = session
        let firstIncomplete = session.prompts.firstIndex(where: { !$0.isCompleted }) ?? 0
        currentPromptIndex = firstIncomplete
        resetExportState()
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

    func addClip(from url: URL, forPromptId: UUID) async -> Bool {
        guard var session = activeSession else {
            errorMessage = ClipImportError.noActiveSession.localizedDescription
            showError = true
            return false
        }

        var copiedClipURL: URL?

        do {
            let durableURL = try await storage.copyClip(url, for: session.id)
            copiedClipURL = durableURL
            let duration = try await videoDuration(for: durableURL)
            let replacement = FilmClip(promptId: forPromptId, fileURL: durableURL, duration: duration)

            let oldClip = session.clip(forPromptId: forPromptId)
            resetExportState()
            guard session.attachClip(replacement) else {
                throw ClipImportError.promptNotFound
            }

            activeSession = session
            saveCurrentSession()

            if let oldClip {
                try? await storage.deleteClipFile(at: oldClip.fileURL)
            }

            return true
        } catch {
            if let copiedClipURL {
                try? await storage.deleteClipFile(at: copiedClipURL)
            }
            errorMessage = "Failed to save clip: \(error.localizedDescription)"
            showError = true
            return false
        }
    }

    func removeClip(_ clip: FilmClip) {
        resetExportState()
        activeSession?.removeClip(clip)
        saveCurrentSession()
        Task {
            try? await storage.deleteClipFile(at: clip.fileURL)
        }
    }

    func reorderClips(from source: IndexSet, to destination: Int) {
        resetExportState()
        activeSession?.clips.move(fromOffsets: source, toOffset: destination)
        saveCurrentSession()
    }

    func canExportActiveSession() -> Bool {
        guard let session = activeSession, !session.clips.isEmpty else { return false }
        return !VideoExportLimits.plan(for: session.clipsInPromptOrder).segments.isEmpty
    }

    func toggleClipTitle(_ clip: FilmClip) {
        guard let index = activeSession?.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        resetExportState()
        activeSession?.clips[index].showTitle.toggle()
        saveCurrentSession()
    }

    func updateClipTitle(_ clip: FilmClip, title: String) {
        guard let index = activeSession?.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        resetExportState()
        activeSession?.clips[index].titleText = title
        saveCurrentSession()
    }

    func setPacingStyle(_ style: PacingStyle) {
        resetExportState()
        activeSession?.pacingStyle = style
        saveCurrentSession()
    }

    func setEditStyle(_ style: EditStyle) {
        resetExportState()
        activeSession?.editStyle = style
        saveCurrentSession()
    }

    func toggleAmbientSoundtrack() {
        activeSession?.useAmbientSoundtrack.toggle()
        saveCurrentSession()
    }

    func exportVideo() async {
        guard let session = activeSession, !session.clips.isEmpty else { return }
        let plan = VideoExportLimits.plan(for: session.clipsInPromptOrder)
        guard !plan.segments.isEmpty else {
            errorMessage = ExportError.noExportableClips.localizedDescription
            showError = true
            return
        }

        isExporting = true
        let exportID = UUID()
        activeExportID = exportID
        exportProgress = 0
        exportedVideoURL = nil
        exportStatusMessage = plan.wasTrimmedToMaximumDuration
            ? "Export will trim at \(Self.formattedDuration(VideoExportLimits.maximumDuration))."
            : "Preparing local export…"
        defer {
            isExporting = false
            activeExportID = nil
        }

        do {
            let url = try await exportService.exportAssembledVideo(
                clips: session.clipsInPromptOrder,
                pacingStyle: session.pacingStyle,
                editStyle: session.editStyle,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        guard self?.activeExportID == exportID, self?.isExporting == true else { return }
                        self?.exportProgress = min(max(progress, 0), 1)
                        self?.exportStatusMessage = "Exporting… \(Int((self?.exportProgress ?? 0) * 100))%"
                    }
                }
            )
            exportedVideoURL = url
            exportProgress = 1
            exportStatusMessage = "Export complete. Opening share sheet…"
            completeSession()
            showExportShare = true
        } catch {
            errorMessage = error.localizedDescription
            exportStatusMessage = "Export failed."
            showError = true
        }
    }

    func completeSession() {
        activeSession?.completedAt = Date()
        saveCurrentSession()
    }

    func deleteSession(_ session: FilmSession) {
        sessions.removeAll { $0.id == session.id }
        if activeSession?.id == session.id {
            activeSession = nil
            currentPromptIndex = 0
            resetExportState()
        }

        let sessionsSnapshot = sessions
        let storage = storage
        let previousTask = pendingPersistenceTask
        pendingPersistenceTask = Task {
            await previousTask?.value
            try? await storage.deleteDraft(for: session.id)
            try? await storage.saveSessions(sessionsSnapshot)
        }
    }

    func saveCurrentSession() {
        guard let session = activeSession else { return }
        upsertSession(session)
        persistSessions()
    }

    func waitForPendingPersistence() async {
        await pendingPersistenceTask?.value
    }

    private func upsertSession(_ session: FilmSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
    }

    private func persistSessions() {
        let sessionsSnapshot = sessions
        let storage = storage
        let previousTask = pendingPersistenceTask
        pendingPersistenceTask = Task { [weak self] in
            await previousTask?.value
            do {
                try await storage.saveSessions(sessionsSnapshot)
            } catch {
                await MainActor.run {
                    self?.errorMessage = "Failed to save draft: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        }
    }

    private func resetExportState() {
        guard !isExporting else { return }
        activeExportID = nil
        exportProgress = 0
        exportStatusMessage = nil
        exportedVideoURL = nil
        showExportShare = false
    }

    private func videoDuration(for url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { throw ClipImportError.invalidDuration }
        return seconds
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
    }
}

nonisolated enum ClipImportError: LocalizedError, Sendable {
    case noActiveSession
    case promptNotFound
    case noVideoSelected
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "Start or resume a film before importing clips."
        case .promptNotFound:
            return "This clip could not be matched to the selected shot prompt."
        case .noVideoSelected:
            return "No video was selected. Choose a clip from your library to attach it to this shot."
        case .invalidDuration:
            return "Could not read a valid video duration. Try a different clip."
        }
    }
}
