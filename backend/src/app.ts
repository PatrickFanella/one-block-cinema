import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from "fastify";
import rawBody from "fastify-raw-body";
import { ZodError } from "zod";
import type { AppConfig } from "./config.js";
import {
  blockInput,
  challengeParams,
  commentInput,
  commentParams,
  critiqueInput,
  muxWebhookInput,
  parseIdempotencyHeader,
  publicationInput,
  reportInput,
  uploadRequestInput,
} from "./contracts.js";
import type { Authenticate, AuthUser } from "./auth.js";
import { queueNames, type JobQueue } from "./jobs.js";
import type { ApiStore } from "./repository.js";
import { verifyMuxSignature } from "./webhook.js";

interface AppDependencies {
  config: AppConfig;
  store: ApiStore;
  jobs: JobQueue;
  authenticate: Authenticate;
}

function mutationKey(request: FastifyRequest): string {
  return parseIdempotencyHeader(request.headers["idempotency-key"]);
}

async function requireUser(request: FastifyRequest, authenticate: Authenticate): Promise<AuthUser> {
  return authenticate(request);
}

function requireCommunity(config: AppConfig): void {
  if (!config.FEATURE_COMMUNITY) {
    throw Object.assign(new Error("Community is not enabled in this environment"), { statusCode: 404 });
  }
}

function sendAccepted(reply: FastifyReply, id: string): FastifyReply {
  return reply.code(202).send({ id, status: "queued" });
}

export async function buildApp(dependencies: AppDependencies): Promise<FastifyInstance> {
  const { config, store, jobs, authenticate } = dependencies;
  const app = Fastify({
    logger: { level: config.LOG_LEVEL },
    requestIdHeader: "x-request-id",
    trustProxy: true,
    bodyLimit: 1_048_576,
  });

  await app.register(helmet);
  await app.register(cors, { origin: false });
  await app.register(rateLimit, { max: 120, timeWindow: "1 minute" });
  await app.register(rawBody, { global: false, encoding: false, runFirst: true });

  app.setErrorHandler((error, request, reply) => {
    const normalized = error instanceof Error ? error : new Error("Unknown request failure");
    const errorWithStatus = normalized as Error & { statusCode?: number };
    const statusCode = normalized instanceof ZodError ? 400 : (errorWithStatus.statusCode ?? 500);
    if (statusCode >= 500) request.log.error({ error: normalized }, "request failed");
    void reply.code(statusCode).send({
      error: normalized instanceof ZodError ? "invalid_request" : normalized.name,
      message: statusCode >= 500 ? "The request could not be completed" : normalized.message,
      requestId: request.id,
    });
  });

  app.get("/healthz", async () => ({ status: "ok", environment: config.APP_ENV }));

  app.post("/v1/publications", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const input = publicationInput.parse(request.body);
    const key = mutationKey(request);
    const publication = await store.idempotent(user.id, key, "create_publication", input, (client) =>
      store.createPublication(client, user.id, input),
    );
    if (publication.status === "pending_review") {
      await jobs.send(
        queueNames.moderatePublication,
        { publicationId: publication.id },
        publication.id,
      );
    }
    return reply.code(201).send(publication);
  });

  app.post("/v1/upload-requests", async (request, reply) => {
    requireCommunity(config);
    await requireUser(request, authenticate);
    uploadRequestInput.parse(request.body);
    mutationKey(request);
    return reply.code(503).send({
      error: "media_provider_unconfigured",
      message: "Published-video upload is disabled until server-side Mux credentials are configured",
      requestId: request.id,
    });
  });

  app.get("/v1/challenges", async (request) => {
    requireCommunity(config);
    await requireUser(request, authenticate);
    return { challenges: await store.listChallenges() };
  });

  app.get("/v1/challenges/:id/submissions", async (request) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const { id } = challengeParams.parse(request.params);
    return { submissions: await store.listSubmissions(id, user.id) };
  });

  app.post("/v1/comments", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const input = commentInput.parse(request.body);
    const key = mutationKey(request);
    const comment = await store.idempotent(user.id, key, "create_comment", input, (client) =>
      store.addComment(client, user.id, input),
    );
    return reply.code(201).send(comment);
  });

  app.delete("/v1/comments/:id", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const { id } = commentParams.parse(request.params);
    const key = mutationKey(request);
    await store.idempotent(user.id, key, "delete_comment", { id }, async (client) => {
      await store.deleteComment(client, id, user.id);
      return { deleted: true };
    });
    return reply.code(204).send();
  });

  app.post("/v1/reports", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const input = reportInput.parse(request.body);
    const key = mutationKey(request);
    const report = await store.idempotent(user.id, key, "create_report", input, (client) =>
      store.createReport(client, user.id, input),
    );
    return reply.code(201).send(report);
  });

  app.post("/v1/blocks", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const input = blockInput.parse(request.body);
    const key = mutationKey(request);
    await store.idempotent(user.id, key, "create_block", input, async (client) => {
      await store.block(client, user.id, input.userId);
      return { blocked: true };
    });
    return reply.code(204).send();
  });

  app.delete("/v1/blocks", async (request, reply) => {
    requireCommunity(config);
    const user = await requireUser(request, authenticate);
    const input = blockInput.parse(request.body);
    const key = mutationKey(request);
    await store.idempotent(user.id, key, "delete_block", input, async (client) => {
      await store.unblock(client, user.id, input.userId);
      return { blocked: false };
    });
    return reply.code(204).send();
  });

  app.post("/v1/critiques", async (request, reply) => {
    const user = await requireUser(request, authenticate);
    const input = critiqueInput.parse(request.body);
    const key = mutationKey(request);
    if (!config.FEATURE_AI_COACH) {
      return reply.code(503).send({
        error: "ai_coach_disabled",
        message: "AI critique is not configured in this environment",
        requestId: request.id,
      });
    }

    const queued = await store.idempotent(user.id, key, "request_critique", input, async (client) => {
      const result = await client.query<{ id: string }>(
        `insert into public.critique_requests (owner_id, project_id, consented_at)
         select $1, p.id, $3 from public.projects p where p.id = $2 and p.owner_id = $1
         returning id`,
        [user.id, input.projectId, input.consentedAt],
      );
      const row = result.rows[0];
      if (!row) throw Object.assign(new Error("The project was not found"), { statusCode: 404 });
      return row;
    });
    const jobId = await jobs.send(queueNames.critique, { critiqueRequestId: queued.id }, queued.id);
    return sendAccepted(reply, jobId);
  });

  app.delete("/v1/account", async (request, reply) => {
    const user = await requireUser(request, authenticate);
    const key = mutationKey(request);
    const queued = await store.idempotent(user.id, key, "delete_account", {}, async (client) => {
      const result = await client.query<{ id: string }>(
        `insert into public.moderation_jobs (kind, status, subject_user_id)
         values ('account_deletion', 'queued', $1) returning id`,
        [user.id],
      );
      const row = result.rows[0];
      if (!row) throw new Error("Failed to queue account deletion");
      return row;
    });
    const jobId = await jobs.send(queueNames.deleteAccount, { userId: user.id }, queued.id);
    return sendAccepted(reply, jobId);
  });

  app.post(
    "/v1/webhooks/mux",
    { config: { rawBody: true }, bodyLimit: 2_097_152 },
    async (request, reply) => {
      if (!config.MUX_WEBHOOK_SECRET) {
        throw Object.assign(new Error("Mux webhooks are not configured"), { statusCode: 503 });
      }
      const rawValue = request.rawBody;
      const raw = typeof rawValue === "string" ? Buffer.from(rawValue) : rawValue;
      const signature = request.headers["mux-signature"];
      if (!raw || !verifyMuxSignature(raw, Array.isArray(signature) ? signature[0] : signature, config.MUX_WEBHOOK_SECRET)) {
        throw Object.assign(new Error("Invalid Mux webhook signature"), { statusCode: 401 });
      }
      const event = muxWebhookInput.parse(request.body);
      await jobs.send(queueNames.muxWebhook, event, event.id);
      return reply.code(202).send({ received: true });
    },
  );

  return app;
}
