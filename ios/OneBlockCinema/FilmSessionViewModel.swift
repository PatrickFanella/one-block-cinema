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

    private let storage = SessionStorage()
    private let exportService = VideoExportService()
    private var activeExportID: UUID?

    var currentPrompt: ShotPrompt? {
        guard let session = activeSession,
              currentPromptIndex < session.prompts.count else { return nil }
        return session.prompts[currentPromptIndex]
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
        let template = TemplateCatalog.template(for: theme)
        let prompts = PromptGenerator.generatePrompts(for: template)
        let session = FilmSession(
            theme: theme,
            templateId: template.id,
            prompts: prompts,
            pacingStyle: template.assemblyGuidance.pacingStyle,
            editStyle: template.assemblyGuidance.editStyle,
            useAmbientSoundtrack: template.assemblyGuidance.useAmbientSoundtrack,
            title: "\(template.displayName) — \(Date().formatted(date: .abbreviated, time: .shortened))"
        )
        activeSession = session
        currentPromptIndex = 0
        resetExportState()
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

    func addClip(from url: URL, forPromptId: UUID) {
        let clip = FilmClip(
            promptId: forPromptId,
            fileURL: url,
            duration: videoDuration(for: url)
        )
        resetExportState()
        activeSession?.clips.append(clip)
        markCurrentPromptCompleted()
    }

    func removeClip(_ clip: FilmClip) {
        resetExportState()
        activeSession?.clips.removeAll { $0.id == clip.id }
        if let promptIndex = activeSession?.prompts.firstIndex(where: { $0.id == clip.promptId }) {
            activeSession?.prompts[promptIndex].isCompleted = false
        }
        saveCurrentSession()
    }

    func reorderClips(from source: IndexSet, to destination: Int) {
        resetExportState()
        activeSession?.clips.move(fromOffsets: source, toOffset: destination)
        saveCurrentSession()
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
        let plan = VideoExportLimits.plan(for: session.clips)
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

    private func resetExportState() {
        guard !isExporting else { return }
        activeExportID = nil
        exportProgress = 0
        exportStatusMessage = nil
        exportedVideoURL = nil
        showExportShare = false
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
    }
}
