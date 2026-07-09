import { Pool } from "pg";
import type { Job } from "pg-boss";
import { loadConfig } from "./config.js";
import { queueNames, startBoss } from "./jobs.js";

interface ModerationJobData {
  publicationId: string;
}

interface MuxWebhookData {
  id: string;
  type: string;
  data: Record<string, unknown>;
}

interface AccountDeletionData {
  userId: string;
}

interface CritiqueJobData {
  critiqueRequestId: string;
}

const config = loadConfig();
const pool = new Pool({ connectionString: config.DATABASE_URL, max: 4 });
const boss = await startBoss(config.DATABASE_URL);

await boss.work<ModerationJobData>(queueNames.moderatePublication, async (jobs: Job<ModerationJobData>[]) => {
  const job = jobs[0];
  if (!job) return;
  await pool.query(
    `with inserted as (
       insert into public.moderation_jobs (kind, status, publication_id)
       values ('publication_review', 'manual_review', $1)
       on conflict (kind, publication_id) where publication_id is not null
       do update set status = 'manual_review', updated_at = now()
       returning id
     )
     update public.publications
        set moderation_status = 'pending_review', updated_at = now()
      where id = $1`,
    [job.data.publicationId],
  );
});

await boss.work<MuxWebhookData>(queueNames.muxWebhook, async (jobs: Job<MuxWebhookData>[]) => {
  const job = jobs[0];
  if (!job) return;
  const uploadId = typeof job.data.data.upload_id === "string" ? job.data.data.upload_id : null;
  const playbackIds = Array.isArray(job.data.data.playback_ids) ? job.data.data.playback_ids : [];
  const firstPlayback = playbackIds[0] as { id?: unknown } | undefined;
  const playbackId = typeof firstPlayback?.id === "string" ? firstPlayback.id : null;

  if (job.data.type === "video.asset.ready" && uploadId && playbackId) {
    await pool.query(
      `update public.publications
          set mux_playback_id = $2, processing_status = 'ready', updated_at = now()
        where mux_upload_id = $1`,
      [uploadId, playbackId],
    );
  } else if (job.data.type === "video.asset.errored" && uploadId) {
    await pool.query(
      `update public.publications
          set processing_status = 'failed', updated_at = now()
        where mux_upload_id = $1`,
      [uploadId],
    );
  }
});

await boss.work<AccountDeletionData>(queueNames.deleteAccount, async (jobs: Job<AccountDeletionData>[]) => {
  const job = jobs[0];
  if (!job) return;
  await pool.query(
    `update public.moderation_jobs
        set status = 'awaiting_external_cleanup', updated_at = now()
      where kind = 'account_deletion' and subject_user_id = $1 and status = 'queued'`,
    [job.data.userId],
  );
});

await boss.work<CritiqueJobData>(queueNames.critique, async (jobs: Job<CritiqueJobData>[]) => {
  const job = jobs[0];
  if (!job) return;
  await pool.query(
    `update public.critique_requests
        set status = 'provider_unconfigured', updated_at = now()
      where id = $1`,
    [job.data.critiqueRequestId],
  );
});

const shutdown = async (): Promise<void> => {
  await boss.stop({ graceful: true });
  await pool.end();
};

process.once("SIGTERM", () => void shutdown().then(() => process.exit(0)));
process.once("SIGINT", () => void shutdown().then(() => process.exit(0)));
