import Foundation

nonisolated enum TemplateAspectRatio: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case vertical = "9:16"
    case square = "1:1"
    case horizontal = "16:9"
    case portrait = "4:5"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .vertical: "Vertical"
        case .square: "Square"
        case .horizontal: "Horizontal"
        case .portrait: "Portrait"
        }
    }

    var widthToHeightRatio: Double {
        switch self {
        case .vertical: 9.0 / 16.0
        case .square: 1
        case .horizontal: 16.0 / 9.0
        case .portrait: 4.0 / 5.0
        }
    }
}

nonisolated struct TemplateDurationTarget: Codable, Sendable, Hashable {
    static let v1MaximumSeconds = 180

    let targetSeconds: Int
    let minimumSeconds: Int
    let maximumSeconds: Int

    enum CodingKeys: String, CodingKey {
        case targetSeconds = "ideal"
        case minimumSeconds = "min"
        case maximumSeconds = "max"
    }

    var fitsV1Maximum: Bool {
        minimumSeconds >= 60
            && minimumSeconds <= targetSeconds
            && targetSeconds <= maximumSeconds
            && maximumSeconds <= Self.v1MaximumSeconds
    }
}

nonisolated struct TemplateShotPrompt: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let index: Int
    let title: String
    let structureRole: String
    let direction: String
    let hint: String
    let icon: String
    let targetSeconds: Int

    func makeSessionPrompt() -> ShotPrompt {
        ShotPrompt(
            templateShotId: id,
            index: index,
            direction: direction,
            hint: hint,
            icon: icon,
            targetSeconds: targetSeconds
        )
    }
}

nonisolated struct TemplateGuidance: Codable, Sendable, Hashable {
    let structure: String
    let capture: String
    let assembly: String
    let export: String
}

nonisolated struct TemplateAssemblyGuidance: Codable, Sendable, Hashable {
    let pacingStyle: PacingStyle
    let editStyle: EditStyle
    let useAmbientSoundtrack: Bool
    let instructions: [String]

    enum CodingKeys: String, CodingKey {
        case pacingStyle
        case editStyle
        case useAmbientSoundtrack
        case instructions
    }

    init(
        pacingStyle: PacingStyle,
        editStyle: EditStyle,
        useAmbientSoundtrack: Bool,
        instructions: [String] = []
    ) {
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
        self.useAmbientSoundtrack = useAmbientSoundtrack
        self.instructions = instructions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pacingStyle = try container.decode(PacingStyle.self, forKey: .pacingStyle)
        editStyle = try container.decode(EditStyle.self, forKey: .editStyle)
        useAmbientSoundtrack = try container.decode(Bool.self, forKey: .useAmbientSoundtrack)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pacingStyle, forKey: .pacingStyle)
        try container.encode(editStyle, forKey: .editStyle)
        try container.encode(useAmbientSoundtrack, forKey: .useAmbientSoundtrack)
        if !instructions.isEmpty {
            try container.encode(instructions, forKey: .instructions)
        }
    }
}

nonisolated struct FilmTemplateV1: Identifiable, Codable, Sendable, Hashable {
    let schemaVersion: Int
    let id: String
    let title: String
    let subtitle: String
    let outcome: String
    let theme: FilmTheme
    let difficulty: String
    let aspectRatio: TemplateAspectRatio
    let durationTargetSeconds: TemplateDurationTarget
    let tags: [String]
    let shotPrompts: [TemplateShotPrompt]
    let guidance: TemplateGuidance
    let assembly: TemplateAssemblyGuidance

    var displayName: String {
        title
    }

    var durationTarget: TemplateDurationTarget {
        durationTargetSeconds
    }

    var shotCount: Int {
        shotPrompts.count
    }

    var prompts: [TemplateShotPrompt] {
        shotPrompts
    }

    var assemblyGuidance: TemplateAssemblyGuidance {
        TemplateAssemblyGuidance(
            pacingStyle: assembly.pacingStyle,
            editStyle: assembly.editStyle,
            useAmbientSoundtrack: assembly.useAmbientSoundtrack,
            instructions: [guidance.structure, guidance.capture, guidance.assembly, guidance.export]
        )
    }
}

typealias FilmTemplate = FilmTemplateV1

nonisolated enum TemplateCatalogError: LocalizedError, Sendable, Equatable {
    case missingCatalog
    case invalidTemplateCount(Int)
    case duplicateTemplateId(String)
    case invalidSchemaVersion(String)
    case invalidDuration(String)
    case invalidPromptOrder(String)
    case duplicatePromptId(templateId: String, promptId: String)

    var errorDescription: String? {
        switch self {
        case .missingCatalog:
            "The bundled film template catalog is missing."
        case let .invalidTemplateCount(count):
            "The launch catalog must contain exactly 10 templates; found \(count)."
        case let .duplicateTemplateId(id):
            "The template id \(id) is duplicated."
        case let .invalidSchemaVersion(id):
            "The template \(id) does not use schema version 1."
        case let .invalidDuration(id):
            "The template \(id) has an invalid duration target."
        case let .invalidPromptOrder(id):
            "The template \(id) has non-contiguous shot prompt indexes."
        case let .duplicatePromptId(templateId, promptId):
            "The shot prompt id \(promptId) is duplicated in template \(templateId)."
        }
    }
}

nonisolated enum TemplateCatalog {
    private static let catalogResourceName = "FilmTemplates"
    private static let expectedTemplateCount = 10

    static let launchTemplates: [FilmTemplate] = {
        do {
            return try loadBundledCatalog()
        } catch {
            assertionFailure("Failed to load film templates: \(error.localizedDescription)")
            return []
        }
    }()

    static func load(from data: Data) throws -> [FilmTemplate] {
        let templates = try JSONDecoder().decode([FilmTemplate].self, from: data)
        try validate(templates)
        return templates
    }

    static func template(id: String) -> FilmTemplate? {
        launchTemplates.first { $0.id == id }
    }

    static func template(for theme: FilmTheme) -> FilmTemplate {
        if let template = launchTemplates.first(where: { $0.theme == theme }) {
            return template
        }

        preconditionFailure("The launch catalog has no template for theme \(theme.rawValue)")
    }

    static func validate(_ templates: [FilmTemplate]) throws {
        guard templates.count == expectedTemplateCount else {
            throw TemplateCatalogError.invalidTemplateCount(templates.count)
        }

        var templateIds: Set<String> = []
        for template in templates {
            guard templateIds.insert(template.id).inserted else {
                throw TemplateCatalogError.duplicateTemplateId(template.id)
            }
            guard template.schemaVersion == 1 else {
                throw TemplateCatalogError.invalidSchemaVersion(template.id)
            }
            guard template.durationTarget.fitsV1Maximum else {
                throw TemplateCatalogError.invalidDuration(template.id)
            }

            let expectedIndexes = Array(0 ..< template.shotPrompts.count)
            guard template.shotPrompts.map(\.index) == expectedIndexes else {
                throw TemplateCatalogError.invalidPromptOrder(template.id)
            }

            var promptIds: Set<String> = []
            for prompt in template.shotPrompts {
                guard promptIds.insert(prompt.id).inserted else {
                    throw TemplateCatalogError.duplicatePromptId(templateId: template.id, promptId: prompt.id)
                }
            }
        }
    }

    private static func loadBundledCatalog() throws -> [FilmTemplate] {
        guard let url = Bundle.main.url(forResource: catalogResourceName, withExtension: "json") else {
            throw TemplateCatalogError.missingCatalog
        }
        return try load(from: Data(contentsOf: url))
    }
}
