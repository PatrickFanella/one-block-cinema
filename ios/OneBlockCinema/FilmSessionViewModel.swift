import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

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
    var storageHealth: DraftStorageHealth = .empty
    var storageCleanupMessage: String?
    var isCleaningStorage: Bool = false
    var interruptedRenders: [InterruptedRender] = []
    var isPreparingLocalDataExport = false
    var localDataExportURL: URL?
    var localDataDeletionMessage: String?

    private let storage: SessionStorage
    private let exportService: any RenderService
    private let backgroundTaskManager: any BackgroundTaskManaging
    private let localDataExportService: LocalDataExportService
    private var pendingPersistenceTask: Task<Void, Never>?
    private var activeExportID: UUID?
    private var backgroundTaskToken: BackgroundTaskToken = .invalid
    private var backgroundTaskExpiredExportID: UUID?
    private var didRecoverInterruptedRenders = false

    init(
        storage: SessionStorage = SessionStorage(),
        localDataExportService: LocalDataExportService = LocalDataExportService(),
        exportService: any RenderService = VideoExportService(),
        backgroundTaskManager: (any BackgroundTaskManaging)? = nil
    ) {
        self.storage = storage
        self.localDataExportService = localDataExportService
        self.exportService = exportService
        self.backgroundTaskManager = backgroundTaskManager ?? ApplicationBackgroundTaskManager()
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

        do {
            storageHealth = try await storage.auditStorage()
        } catch {
            storageHealth = .empty
            errorMessage = "Drafts loaded, but storage recovery could not be checked: \(error.localizedDescription)"
            showError = true
        }

        if !didRecoverInterruptedRenders {
            didRecoverInterruptedRenders = true
            do {
                interruptedRenders = try await storage.recoverInterruptedRenders()
            } catch {
                didRecoverInterruptedRenders = false
                interruptedRenders = []
                errorMessage = "Drafts loaded, but interrupted exports could not be checked: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func startNewSession(theme: FilmTheme) {
        createDraft(template: TemplateCatalog.template(for: theme))
    }

    func startNewSession(template: FilmTemplate) {
        createDraft(template: template)
    }

    @discardableResult
    func createDraft(theme: FilmTheme) -> FilmSession {
        createDraft(template: TemplateCatalog.template(for: theme))
    }

    @discardableResult
    func createDraft(template: FilmTemplate) -> FilmSession {
        let prompts = PromptGenerator.generatePrompts(for: template)
        let session = FilmSession(
            theme: template.theme,
            templateId: template.id,
            templateSchemaVersion: template.schemaVersion,
            templateTitle: template.title,
            templateOutcome: template.outcome,
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
        let missingPromptId = session.clips.first(where: { $0.mediaStatus == .missing })?.promptId
        let firstMissing = missingPromptId.flatMap { id in
            session.prompts.firstIndex(where: { $0.id == id })
        }
        currentPromptIndex = firstMissing
            ?? session.prompts.firstIndex(where: { !$0.isCompleted })
            ?? 0
        resetExportState()
    }

    func cleanupUnusedMedia() async {
        guard !isCleaningStorage else { return }
        isCleaningStorage = true
        storageCleanupMessage = nil
        defer { isCleaningStorage = false }
        await pendingPersistenceTask?.value

        do {
            let result = try await storage.cleanupOrphanedMedia()
            storageHealth = try await storage.auditStorage()
            storageCleanupMessage = result.removedFileCount == 0
                ? "No unused media was ready to remove."
                : "Removed \(result.removedFileCount) unused file\(result.removedFileCount == 1 ? "" : "s") and reclaimed \(Self.formattedBytes(result.reclaimedBytes))."
        } catch {
            errorMessage = "Could not clean up unused media: \(error.localizedDescription)"
            showError = true
        }
    }

    func dismissInterruptedRenders() async {
        do {
            try await storage.dismissInterruptedRenders()
            interruptedRenders = []
        } catch {
            errorMessage = "Could not dismiss the export recovery notice: \(error.localizedDescription)"
            showError = true
        }
    }

    func prepareLocalDataExport() async {
        guard !isPreparingLocalDataExport else { return }
        isPreparingLocalDataExport = true
        localDataExportURL = nil
        defer { isPreparingLocalDataExport = false }
        await pendingPersistenceTask?.value

        do {
            let recoveryIssues = try await storage.loadRecoveryIssues()
            localDataExportURL = try await localDataExportService.export(
                sessions: sessions,
                recoveryIssues: recoveryIssues
            )
        } catch {
            errorMessage = "Could not prepare your local data export: \(error.localizedDescription)"
            showError = true
        }
    }

    func deleteAllLocalData() async {
        guard !isExporting else {
            errorMessage = "Wait for the current film export to finish or cancel it before deleting local data."
            showError = true
            return
        }
        await pendingPersistenceTask?.value

        do {
            try await storage.deleteAllLocalData()
            sessions = []
            activeSession = nil
            currentPromptIndex = 0
            interruptedRenders = []
            storageHealth = .empty
            storageCleanupMessage = nil
            localDataExportURL = nil
            localDataDeletionMessage = "All local project data and app-owned draft media were deleted."
            resetExportState()
        } catch {
            await loadSessions()
            errorMessage = "Local data deletion did not finish: \(error.localizedDescription)"
            showError = true
        }
    }

    func hasInterruptedRender(for projectId: UUID) -> Bool {
        interruptedRenders.contains { $0.projectId == projectId }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .background, isExporting else { return }
        exportStatusMessage = "Continuing local export in the background…"
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
              index >= 0, index < session.prompts.count else { return }
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
            await pendingPersistenceTask?.value

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
        let persistenceTask = pendingPersistenceTask
        Task {
            await persistenceTask?.value
            try? await storage.deleteClipFile(at: clip.fileURL)
        }
    }

    func reorderClips(from source: IndexSet, to destination: Int) {
        guard var session = activeSession else { return }
        var orderedClips = session.clipsInEditOrder
        orderedClips.move(fromOffsets: source, toOffset: destination)
        resetExportState()
        session.setClipOrder(orderedClips.map(\.id))
        activeSession = session
        saveCurrentSession()
    }

    func moveClip(_ clip: FilmClip, by offset: Int) {
        guard var session = activeSession else { return }
        var orderedClips = session.clipsInEditOrder
        guard let source = orderedClips.firstIndex(where: { $0.id == clip.id }) else { return }
        let destination = source + offset
        guard orderedClips.indices.contains(destination) else { return }
        orderedClips.swapAt(source, destination)
        resetExportState()
        session.setClipOrder(orderedClips.map(\.id))
        activeSession = session
        saveCurrentSession()
    }

    func updateClipTrim(id: UUID, start: TimeInterval, end: TimeInterval) {
        updateClipEdits(id: id, start: start, end: end)
    }

    func updateClipEdits(
        id: UUID,
        start: TimeInterval,
        end: TimeInterval,
        showTitle: Bool? = nil,
        title: String? = nil,
        volume: Double? = nil,
        transitionStyle: TransitionStyle? = nil
    ) {
        guard let index = activeSession?.clips.firstIndex(where: { $0.id == id }),
              let duration = activeSession?.clips[index].duration,
              duration > 0 else { return }
        let minimumDuration = min(0.1, duration)
        let clampedStart = min(max(start, 0), max(0, duration - minimumDuration))
        let clampedEnd = min(max(end, clampedStart + minimumDuration), duration)
        resetExportState()
        activeSession?.clips[index].trimStart = clampedStart
        activeSession?.clips[index].trimEnd = clampedEnd >= duration ? nil : clampedEnd
        if let showTitle {
            activeSession?.clips[index].showTitle = showTitle
        }
        if let title {
            activeSession?.clips[index].titleText = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        }
        if let volume {
            activeSession?.clips[index].volume = min(max(volume, 0), 1)
        }
        if let transitionStyle {
            activeSession?.clips[index].transitionStyle = transitionStyle
        }
        saveCurrentSession()
    }

    func canExportActiveSession() -> Bool {
        guard let session = activeSession, !session.clips.isEmpty else { return false }
        return !VideoExportLimits.plan(for: session).segments.isEmpty
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

    func attachAudioTrack(from url: URL, kind: ProjectAudioTrackKind) async -> Bool {
        guard var session = activeSession else {
            errorMessage = "Start or resume a film before adding audio."
            showError = true
            return false
        }
        var copiedURL: URL?
        do {
            let duration = try await audioDuration(for: url)
            let durableURL = try await storage.copyAudio(url, for: session.id)
            copiedURL = durableURL
            let oldTrack = session.audioTrack(kind: kind)
            let defaultVolume = kind == .voiceover ? 1.0 : 0.25
            session.setAudioTrack(
                ProjectAudioTrack(
                    kind: kind,
                    fileURL: durableURL,
                    duration: duration,
                    volume: oldTrack?.volume ?? defaultVolume
                )
            )
            if kind == .ambient {
                session.useAmbientSoundtrack = true
            }
            resetExportState()
            activeSession = session
            saveCurrentSession()
            await pendingPersistenceTask?.value
            if let oldTrack {
                try? await storage.deleteClipFile(at: oldTrack.fileURL)
            }
            return true
        } catch {
            if let copiedURL {
                try? await storage.deleteClipFile(at: copiedURL)
            }
            errorMessage = "Could not add audio: \(error.localizedDescription)"
            showError = true
            return false
        }
    }

    func removeAudioTrack(kind: ProjectAudioTrackKind) {
        guard let track = activeSession?.audioTrack(kind: kind) else { return }
        resetExportState()
        activeSession?.removeAudioTrack(kind: kind)
        if kind == .ambient {
            activeSession?.useAmbientSoundtrack = false
        }
        saveCurrentSession()
        let persistenceTask = pendingPersistenceTask
        Task {
            await persistenceTask?.value
            try? await storage.deleteClipFile(at: track.fileURL)
        }
    }

    func updateAudioTrackVolume(kind: ProjectAudioTrackKind, volume: Double) {
        resetExportState()
        activeSession?.setAudioTrackVolume(kind: kind, volume: volume)
        saveCurrentSession()
    }

    func addIntertitle(text: String, duration: TimeInterval, position: Int) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        resetExportState()
        activeSession?.addIntertitle(
            IntertitleCard(text: text, duration: duration, position: position)
        )
        saveCurrentSession()
    }

    func updateIntertitle(_ card: IntertitleCard) {
        resetExportState()
        activeSession?.updateIntertitle(card)
        saveCurrentSession()
    }

    func removeIntertitle(id: UUID) {
        resetExportState()
        activeSession?.removeIntertitle(id: id)
        saveCurrentSession()
    }

    func exportVideo() async {
        guard let session = activeSession, !session.clips.isEmpty else { return }
        let plan = VideoExportLimits.plan(for: session)
        guard !plan.segments.isEmpty else {
            errorMessage = ExportError.noExportableClips.localizedDescription
            showError = true
            return
        }

        await pendingPersistenceTask?.value
        let exportID = UUID()
        do {
            try await storage.beginRender(id: exportID, projectId: session.id)
            interruptedRenders.removeAll { $0.projectId == session.id }
        } catch {
            errorMessage = "Export could not start safely: \(error.localizedDescription)"
            showError = true
            return
        }

        isExporting = true
        activeExportID = exportID
        beginBackgroundTask(for: exportID)
        exportProgress = 0
        exportedVideoURL = nil
        exportStatusMessage = plan.wasTrimmedToMaximumDuration
            ? "Export will trim at \(Self.formattedDuration(VideoExportLimits.maximumDuration))."
            : "Preparing local export…"
        defer {
            endBackgroundTask()
            isExporting = false
            activeExportID = nil
            if backgroundTaskExpiredExportID == exportID {
                backgroundTaskExpiredExportID = nil
            }
        }

        do {
            let url = try await exportService.render(
                plan: plan,
                progress: { [self] progress in
                    Task { @MainActor in
                        guard activeExportID == exportID, isExporting else { return }
                        exportProgress = min(max(progress, 0), 1)
                        exportStatusMessage = "Exporting… \(Int(exportProgress * 100))%"
                    }
                }
            )
            activeExportID = nil
            exportedVideoURL = url
            exportProgress = 1
            exportStatusMessage = "Export complete. Opening share sheet…"
            try? await storage.markRenderCompleted(id: exportID)
            completeSession()
            showExportShare = true
        } catch is CancellationError {
            exportProgress = 0
            if backgroundTaskExpiredExportID == exportID {
                exportStatusMessage = "Export paused when background time ended. Your draft is safe; export again to retry."
            } else {
                try? await storage.markRenderCancelled(id: exportID)
                exportStatusMessage = "Export cancelled. Your draft is unchanged."
            }
        } catch ExportError.criticalThermalState {
            exportProgress = 0
            try? await storage.markRenderInterrupted(id: exportID, reason: "critical_thermal_state")
            exportStatusMessage = "Export paused because this device is too hot. Your draft is safe; retry after it cools down."
            errorMessage = ExportError.criticalThermalState.localizedDescription
            showError = true
        } catch {
            try? await storage.markRenderFailed(id: exportID, reason: String(describing: error))
            errorMessage = error.localizedDescription
            exportStatusMessage = "Export failed."
            showError = true
        }
    }

    func cancelExport() {
        guard isExporting else { return }
        activeExportID = nil
        exportStatusMessage = "Cancelling export…"
        Task { await exportService.cancelCurrentRender() }
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

    private func beginBackgroundTask(for exportID: UUID) {
        guard backgroundTaskToken == .invalid else { return }
        backgroundTaskToken = backgroundTaskManager.begin(name: "OneBlockCinemaExport") { [weak self] in
            Task { @MainActor [weak self] in
                await self?.interruptExportWhenBackgroundTimeExpires(exportID: exportID)
            }
        }
    }

    private func interruptExportWhenBackgroundTimeExpires(exportID: UUID) async {
        guard activeExportID == exportID, isExporting else {
            endBackgroundTask()
            return
        }
        backgroundTaskExpiredExportID = exportID
        exportStatusMessage = "Background time ended. Pausing export safely…"
        try? await storage.markRenderInterrupted(id: exportID, reason: "background_time_expired")
        await exportService.cancelCurrentRender()
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTaskToken != .invalid else { return }
        backgroundTaskManager.end(backgroundTaskToken)
        backgroundTaskToken = .invalid
    }

    private func videoDuration(for url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { throw ClipImportError.invalidDuration }
        return seconds
    }

    private func audioDuration(for url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            throw ProjectAudioError.noAudioTrack
        }
        let duration = try await CMTimeGetSeconds(asset.load(.duration))
        guard duration.isFinite, duration > 0 else { throw ProjectAudioError.invalidDuration }
        return min(duration, VideoExportLimits.maximumDuration)
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

nonisolated enum ProjectAudioError: LocalizedError, Sendable {
    case noAudioTrack
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            "The selected file does not contain a readable audio track."
        case .invalidDuration:
            "The selected audio has an invalid duration."
        }
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
            "Start or resume a film before importing clips."
        case .promptNotFound:
            "This clip could not be matched to the selected shot prompt."
        case .noVideoSelected:
            "No video was selected. Choose a clip from your library to attach it to this shot."
        case .invalidDuration:
            "Could not read a valid video duration. Try a different clip."
        }
    }
}
