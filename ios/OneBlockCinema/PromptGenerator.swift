import Foundation

struct PromptGenerator {
    static func generatePrompts(for theme: FilmTheme) -> [ShotPrompt] {
        generatePrompts(for: TemplateCatalog.template(for: theme))
    }

    static func generatePrompts(for template: FilmTemplate) -> [ShotPrompt] {
        template.prompts.map { $0.makeSessionPrompt() }
    }
}
