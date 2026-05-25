import Foundation

nonisolated struct FilmSession: Identifiable, Codable, Sendable {
    let id: UUID
    let templateId: String?
    let theme: FilmTheme
    let aspectRatio: TemplateAspectRatio?
    let durationTargetSeconds: TemplateDurationTarget?
    let guidance: TemplateGuidance?
    var prompts: [ShotPrompt]
    var clips: [FilmClip]
    var pacingStyle: PacingStyle
    var editStyle: EditStyle
    var useAmbientSoundtrack: Bool
    let createdAt: Date
    var completedAt: Date?
    var title: String

    init(
        id: UUID = UUID(),
        templateId: String? = nil,
        theme: FilmTheme,
        aspectRatio: TemplateAspectRatio? = nil,
        durationTargetSeconds: TemplateDurationTarget? = nil,
        guidance: TemplateGuidance? = nil,
        prompts: [ShotPrompt] = [],
        clips: [FilmClip] = [],
        pacingStyle: PacingStyle = .rhythmic,
        editStyle: EditStyle = .standard,
        useAmbientSoundtrack: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        title: String = ""
    ) {
        self.id = id
        self.templateId = templateId
        self.theme = theme
        self.aspectRatio = aspectRatio
        self.durationTargetSeconds = durationTargetSeconds
        self.guidance = guidance
        self.prompts = prompts
        self.clips = clips
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
        self.useAmbientSoundtrack = useAmbientSoundtrack
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.title = title
    }

    var isComplete: Bool {
        !clips.isEmpty && prompts.allSatisfy(\.isCompleted)
    }

    var completedPromptCount: Int {
        prompts.filter(\.isCompleted).count
    }

    var progress: Double {
        guard !prompts.isEmpty else { return 0 }
        return Double(completedPromptCount) / Double(prompts.count)
    }
}
