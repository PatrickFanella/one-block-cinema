import Foundation

nonisolated enum AppEnvironment: String, Codable, Sendable, CaseIterable {
    case development
    case staging
    case production
}

nonisolated struct AppConfiguration: Sendable, Equatable {
    let environment: AppEnvironment
    let apiBaseURL: URL?
    let supabaseURL: URL?
    let communityEnabled: Bool
    let aiCoachEnabled: Bool

    static var current: AppConfiguration {
        AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        environment = AppEnvironment(
            rawValue: Self.string(infoDictionary["OBCEnvironment"])?.lowercased() ?? ""
        ) ?? .development
        apiBaseURL = Self.validatedURL(
            Self.string(infoDictionary["OBCAPIBaseURL"]),
            environment: environment
        )
        supabaseURL = Self.validatedURL(
            Self.string(infoDictionary["OBCSupabaseURL"]),
            environment: environment
        )

        let requestedCommunity = Self.bool(infoDictionary["OBCFeatureCommunity"])
        let requestedAI = Self.bool(infoDictionary["OBCFeatureAICoach"])
        communityEnabled = requestedCommunity && apiBaseURL != nil && supabaseURL != nil
        aiCoachEnabled = requestedAI && apiBaseURL != nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        guard let value = string(value)?.lowercased() else { return false }
        return ["1", "true", "yes"].contains(value)
    }

    private static func validatedURL(_ value: String?, environment: AppEnvironment) -> URL? {
        guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        if environment == .production {
            return scheme == "https" ? url : nil
        }
        if scheme == "https" { return url }
        if scheme == "http", ["localhost", "127.0.0.1"].contains(url.host?.lowercased() ?? "") {
            return url
        }
        return nil
    }
}

enum Config {
    static var app: AppConfiguration { .current }
}
