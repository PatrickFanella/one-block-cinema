import { createHash } from "node:crypto";
import { Pool, type PoolClient } from "pg";

export class IdempotencyConflictError extends Error {
  readonly statusCode = 409;
}

export class NotFoundError extends Error {
  readonly statusCode = 404;
}

export interface PublicationRecord {
  id: string;
  projectId: string;
  ownerId: string;
  challengeId: string | null;
  visibility: string;
  status: string;
  caption: string;
  commentsEnabled: boolean;
  createdAt: string;
}

export interface CommentRecord {
  id: string;
  publicationId: string;
  authorId: string;
  body: string;
  feedbackPromptId: string | null;
  createdAt: string;
}

export interface ApiStore {
  idempotent<T>(
    ownerId: string,
    key: string,
    operation: string,
    request: unknown,
    work: (client: PoolClient) => Promise<T>,
  ): Promise<T>;
  createPublication(
    client: PoolClient,
    ownerId: string,
    input: {
      projectId: string;
      challengeId?: string | undefined;
      visibility: "private" | "unlisted" | "public";
      caption: string;
      commentsEnabled: boolean;
    },
  ): Promise<PublicationRecord>;
  listChallenges(): Promise<unknown[]>;
  listSubmissions(challengeId: string, viewerId: string): Promise<unknown[]>;
  addComment(
    client: PoolClient,
    authorId: string,
    input: { publicationId: string; body: string; feedbackPromptId?: string | undefined },
  ): Promise<CommentRecord>;
  deleteComment(client: PoolClient, id: string, authorId: string): Promise<void>;
  createReport(
    client: PoolClient,
    reporterId: string,
    input: { publicationId?: string | undefined; commentId?: string | undefined; reason: string },
  ): Promise<{ id: string; status: string }>;
  block(client: PoolClient, blockerId: string, blockedId: string): Promise<void>;
  unblock(client: PoolClient, blockerId: string, blockedId: string): Promise<void>;
}

interface SyncOperationRow {
  request_hash: string;
  response: unknown | null;
  status: string;
}

export class PostgresApiStore implements ApiStore {
  constructor(private readonly pool: Pool) {}

  async idempotent<T>(
    ownerId: string,
    key: string,
    operation: string,
    request: unknown,
    work: (client: PoolClient) => Promise<T>,
  ): Promise<T> {
    const client = await this.pool.connect();
    const requestHash = createHash("sha256").update(JSON.stringify(request)).digest("hex");
    try {
      await client.query("begin");
      const reservation = await client.query<{ id: string }>(
        `insert into public.sync_operations
          (owner_id, idempotency_key, operation, request_hash, status)
         values ($1, $2, $3, $4, 'processing')
         on conflict (owner_id, idempotency_key, operation) do nothing
         returning id`,
        [ownerId, key, operation, requestHash],
      );

      if (reservation.rowCount === 0) {
        const existing = await client.query<SyncOperationRow>(
          `select request_hash, response, status
             from public.sync_operations
            where owner_id = $1 and idempotency_key = $2 and operation = $3
            for update`,
          [ownerId, key, operation],
        );
        const row = existing.rows[0];
        if (!row || row.request_hash !== requestHash) {
          throw new IdempotencyConflictError("The idempotency key was already used for a different request");
        }
        if (row.status !== "completed" || row.response === null) {
          throw new IdempotencyConflictError("The matching request is still being processed");
        }
        await client.query("commit");
        return row.response as T;
      }

      const result = await work(client);
      await client.query(
        `update public.sync_operations
            set status = 'completed', response = $4::jsonb, completed_at = now()
          where owner_id = $1 and idempotency_key = $2 and operation = $3`,
        [ownerId, key, operation, JSON.stringify(result)],
      );
      await client.query("commit");
      return result;
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
  }

  async createPublication(
    client: PoolClient,
    ownerId: string,
    input: {
      projectId: string;
      challengeId?: string | undefined;
      visibility: "private" | "unlisted" | "public";
      caption: string;
      commentsEnabled: boolean;
    },
  ): Promise<PublicationRecord> {
    const result = await client.query<PublicationRecord>(
      `insert into public.publications
        (project_id, owner_id, challenge_id, visibility, moderation_status, caption, comments_enabled)
       select p.id, p.owner_id, $3, $4,
              case when $4 = 'private' then 'draft' else 'pending_review' end,
              $5, $6
         from public.projects p
        where p.id = $1 and p.owner_id = $2
       returning id, project_id as "projectId", owner_id as "ownerId",
                 challenge_id as "challengeId", visibility,
                 moderation_status as status, caption,
                 comments_enabled as "commentsEnabled", created_at as "createdAt"`,
      [
        input.projectId,
        ownerId,
        input.challengeId ?? null,
        input.visibility,
        input.caption,
        input.commentsEnabled,
      ],
    );
    const publication = result.rows[0];
    if (!publication) throw new NotFoundError("The project was not found");
    return publication;
  }

  async listChallenges(): Promise<unknown[]> {
    const result = await this.pool.query(
      `select id, title, prompt, template_id as "templateId", cadence,
              starts_at as "startsAt", ends_at as "endsAt"
         from public.challenges
        where status = 'active' and starts_at <= now() and ends_at > now()
        order by starts_at desc`,
    );
    return result.rows;
  }

  async listSubmissions(challengeId: string, viewerId: string): Promise<unknown[]> {
    const result = await this.pool.query(
      `select p.id, p.owner_id as "ownerId", p.challenge_id as "challengeId",
              p.caption, p.mux_playback_id as "playbackId", p.created_at as "createdAt"
         from public.publications p
        where p.challenge_id = $1
          and p.visibility = 'public'
          and p.moderation_status = 'approved'
          and not exists (
            select 1 from public.blocks b
             where (b.blocker_id = $2 and b.blocked_id = p.owner_id)
                or (b.blocker_id = p.owner_id and b.blocked_id = $2)
          )
        order by p.created_at desc
        limit 100`,
      [challengeId, viewerId],
    );
    return result.rows;
  }

  async addComment(
    client: PoolClient,
    authorId: string,
    input: { publicationId: string; body: string; feedbackPromptId?: string | undefined },
  ): Promise<CommentRecord> {
    const result = await client.query<CommentRecord>(
      `insert into public.comments
        (publication_id, author_id, body, feedback_prompt_id)
       select p.id, $2, $3, $4
         from public.publications p
        where p.id = $1
          and p.moderation_status = 'approved'
          and p.comments_enabled
          and not exists (
            select 1 from public.blocks b
             where (b.blocker_id = $2 and b.blocked_id = p.owner_id)
                or (b.blocker_id = p.owner_id and b.blocked_id = $2)
          )
       returning id, publication_id as "publicationId", author_id as "authorId",
                 body, feedback_prompt_id as "feedbackPromptId", created_at as "createdAt"`,
      [input.publicationId, authorId, input.body, input.feedbackPromptId ?? null],
    );
    const comment = result.rows[0];
    if (!comment) throw new NotFoundError("The publication is unavailable for comments");
    return comment;
  }

  async deleteComment(client: PoolClient, id: string, authorId: string): Promise<void> {
    const result = await client.query(
      `update public.comments set deleted_at = now(), body = ''
        where id = $1 and author_id = $2 and deleted_at is null`,
      [id, authorId],
    );
    if (result.rowCount === 0) throw new NotFoundError("The comment was not found");
  }

  async createReport(
    client: PoolClient,
    reporterId: string,
    input: { publicationId?: string | undefined; commentId?: string | undefined; reason: string },
  ): Promise<{ id: string; status: string }> {
    const result = await client.query<{ id: string; status: string }>(
      `insert into public.reports (reporter_id, publication_id, comment_id, reason)
       values ($1, $2, $3, $4)
       returning id, status`,
      [reporterId, input.publicationId ?? null, input.commentId ?? null, input.reason],
    );
    const report = result.rows[0];
    if (!report) throw new Error("Report creation failed");
    return report;
  }

  async block(client: PoolClient, blockerId: string, blockedId: string): Promise<void> {
    if (blockerId === blockedId) throw new IdempotencyConflictError("A user cannot block themselves");
    await client.query(
      `insert into public.blocks (blocker_id, blocked_id)
       values ($1, $2) on conflict (blocker_id, blocked_id) do nothing`,
      [blockerId, blockedId],
    );
  }

  async unblock(client: PoolClient, blockerId: string, blockedId: string): Promise<void> {
    await client.query(`delete from public.blocks where blocker_id = $1 and blocked_id = $2`, [
      blockerId,
      blockedId,
    ]);
  }
}
