import Foundation

nonisolated protocol TemplateRepository: Sendable {
    func allTemplates() async throws -> [FilmTemplateV1]
    func template(id: String) async throws -> FilmTemplateV1?
}

nonisolated struct BundledTemplateRepository: TemplateRepository {
    func allTemplates() async throws -> [FilmTemplateV1] {
        TemplateCatalog.launchTemplates
    }

    func template(id: String) async throws -> FilmTemplateV1? {
        TemplateCatalog.template(id: id)
    }
}

nonisolated protocol ProjectRepository: Sendable {
    func loadProjects() async throws -> [FilmProject]
    func saveProjects(_ projects: [FilmProject]) async throws
    func deleteProject(id: UUID) async throws
    func recoveryIssues() async throws -> [DraftRecoveryIssue]
}

nonisolated protocol MediaStore: Sendable {
    func importMedia(from sourceURL: URL, projectId: UUID) async throws -> URL
    func deleteMedia(at url: URL) async throws
}

nonisolated protocol RenderService: Sendable {
    func makePlan(for project: FilmProject) async throws -> RenderPlan
    func render(
        plan: RenderPlan,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
    func cancelCurrentRender() async
}

nonisolated enum AuthProvider: String, Codable, Sendable, Hashable {
    case emailOTP = "email_otp"
    case apple
    case google
}

nonisolated struct AuthSession: Codable, Sendable, Hashable {
    let userId: UUID
    let provider: AuthProvider
    let expiresAt: Date
}

nonisolated protocol AuthService: Sendable {
    func currentSession() async throws -> AuthSession?
    func requestEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws -> AuthSession
    func signIn(provider: AuthProvider) async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
}

nonisolated struct SyncSummary: Codable, Sendable, Hashable {
    let uploadedProjects: Int
    let downloadedProjects: Int
    let recoveredConflicts: Int
}

nonisolated protocol SyncService: Sendable {
    func syncPendingChanges() async throws -> SyncSummary
    func enableSync(projectId: UUID) async throws
    func disableSync(projectId: UUID) async throws
}

nonisolated protocol SyncOperationStore: Sendable {
    func enqueue(
        aggregateId: UUID,
        kind: SyncOperationKind,
        payload: Data,
        idempotencyKey: UUID
    ) async throws -> SyncOutboxOperation
    func pendingOperations(limit: Int, now: Date) async throws -> [SyncOutboxOperation]
    func markProcessing(id: UUID) async throws
    func markFailed(id: UUID, error: String, retryAt: Date) async throws
    func markCompleted(id: UUID) async throws
}

nonisolated protocol CommunityService: Sendable {
    func challenges() async throws -> [Challenge]
    func submissions(challengeId: UUID) async throws -> [Publication]
    func publish(_ publication: Publication, idempotencyKey: UUID) async throws -> Publication
    func addComment(_ comment: Comment, idempotencyKey: UUID) async throws -> Comment
    func deleteComment(id: UUID, idempotencyKey: UUID) async throws
    func report(_ report: Report, idempotencyKey: UUID) async throws
    func block(userId: UUID, idempotencyKey: UUID) async throws
    func unblock(userId: UUID, idempotencyKey: UUID) async throws
}

/// The cloud implementation remains intentionally absent until AI critique is configured.
nonisolated protocol CritiqueService: Sendable {
    func requestCritique(projectId: UUID, consentedAt: Date) async throws -> CritiqueResult
}

nonisolated struct AnalyticsEvent: Codable, Sendable, Hashable {
    let name: String
    let timestamp: Date
    let properties: [String: String]
}

nonisolated protocol Analytics: Sendable {
    func record(_ event: AnalyticsEvent) async
}

extension SessionStorage: ProjectRepository, MediaStore, SyncOperationStore {
    func loadProjects() async throws -> [FilmProject] {
        try loadSessions()
    }

    func saveProjects(_ projects: [FilmProject]) async throws {
        try saveSessions(projects)
    }

    func deleteProject(id: UUID) async throws {
        try deleteDraft(for: id)
    }

    func recoveryIssues() async throws -> [DraftRecoveryIssue] {
        try loadRecoveryIssues()
    }

    func importMedia(from sourceURL: URL, projectId: UUID) async throws -> URL {
        try copyClip(sourceURL, for: projectId)
    }

    func deleteMedia(at url: URL) async throws {
        try deleteClipFile(at: url)
    }

    func enqueue(
        aggregateId: UUID,
        kind: SyncOperationKind,
        payload: Data,
        idempotencyKey: UUID
    ) async throws -> SyncOutboxOperation {
        try enqueueSyncOperation(
            aggregateId: aggregateId,
            kind: kind,
            payload: payload,
            idempotencyKey: idempotencyKey
        )
    }

    func pendingOperations(limit: Int, now: Date) async throws -> [SyncOutboxOperation] {
        try loadPendingSyncOperations(limit: limit, now: now)
    }
}
