import { Pool } from "pg";
import type { Job } from "pg-boss";
import {
  executeAccountDeletion,
  MuxAssetDeletionProvider,
  PostgresAccountDeletionRepository,
  SupabaseAuthDeletionProvider,
  SupabaseStorageDeletionProvider,
} from "./account-deletion.js";
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
  deletionJobId: string;
}

interface CritiqueJobData {
  critiqueRequestId: string;
}

const config = loadConfig();
const pool = new Pool({ connectionString: config.DATABASE_URL, max: 4 });
const boss = await startBoss(config.DATABASE_URL);
const accountDeletionRepository = new PostgresAccountDeletionRepository(pool);
const storageDeletionProvider = config.SUPABASE_SERVICE_ROLE_KEY
  ? new SupabaseStorageDeletionProvider(config.SUPABASE_URL, config.SUPABASE_SERVICE_ROLE_KEY)
  : null;
const authDeletionProvider = config.SUPABASE_SERVICE_ROLE_KEY
  ? new SupabaseAuthDeletionProvider(config.SUPABASE_URL, config.SUPABASE_SERVICE_ROLE_KEY)
  : null;
const muxDeletionProvider = config.MUX_TOKEN_ID && config.MUX_TOKEN_SECRET
  ? new MuxAssetDeletionProvider(config.MUX_TOKEN_ID, config.MUX_TOKEN_SECRET)
  : null;

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
    const assetId = typeof job.data.data.id === "string" ? job.data.data.id : null;
    await pool.query(
      `update public.publications
          set mux_playback_id = $2, mux_asset_id = $3,
              processing_status = 'ready', updated_at = now()
        where mux_upload_id = $1`,
      [uploadId, playbackId, assetId],
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
  await executeAccountDeletion(
    job.data.deletionJobId,
    job.data.userId,
    accountDeletionRepository,
    {
      storage: storageDeletionProvider,
      mux: muxDeletionProvider,
      auth: authDeletionProvider,
      apple: null,
    },
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
