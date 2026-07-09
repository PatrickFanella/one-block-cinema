import type { Pool } from "pg";

export interface AccountDeletionResources {
  storagePaths: string[];
  muxAssetIds: string[];
  hasAppleIdentity: boolean;
}

export interface AccountDeletionRepository {
  begin(jobId: string, userId: string): Promise<boolean>;
  resources(userId: string): Promise<AccountDeletionResources>;
  complete(jobId: string): Promise<void>;
  fail(jobId: string, code: string): Promise<void>;
}

export interface StorageDeletionProvider {
  remove(paths: string[]): Promise<void>;
}

export interface MuxDeletionProvider {
  remove(assetIds: string[]): Promise<void>;
}

export interface AuthDeletionProvider {
  remove(userId: string): Promise<void>;
}

export interface AppleRevocationProvider {
  revoke(userId: string): Promise<void>;
}

export interface AccountDeletionProviders {
  storage: StorageDeletionProvider | null;
  mux: MuxDeletionProvider | null;
  auth: AuthDeletionProvider | null;
  apple: AppleRevocationProvider | null;
}

export class AccountDeletionFailure extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "AccountDeletionFailure";
  }
}

export async function executeAccountDeletion(
  jobId: string,
  userId: string,
  repository: AccountDeletionRepository,
  providers: AccountDeletionProviders,
): Promise<"completed" | "already_completed"> {
  const shouldRun = await repository.begin(jobId, userId);
  if (!shouldRun) return "already_completed";

  try {
    const resources = await repository.resources(userId);
    if (resources.hasAppleIdentity) {
      if (!providers.apple) {
        throw new AccountDeletionFailure(
          "apple_revocation_unconfigured",
          "Sign in with Apple revocation is not configured",
        );
      }
      await providers.apple.revoke(userId);
    }

    if (resources.storagePaths.length > 0) {
      if (!providers.storage) {
        throw new AccountDeletionFailure("storage_cleanup_unconfigured", "Storage cleanup is not configured");
      }
      await providers.storage.remove(resources.storagePaths);
    }

    if (resources.muxAssetIds.length > 0) {
      if (!providers.mux) {
        throw new AccountDeletionFailure("mux_cleanup_unconfigured", "Mux cleanup is not configured");
      }
      await providers.mux.remove(resources.muxAssetIds);
    }

    if (!providers.auth) {
      throw new AccountDeletionFailure("auth_cleanup_unconfigured", "Auth cleanup is not configured");
    }
    await providers.auth.remove(userId);
    await repository.complete(jobId);
    return "completed";
  } catch (error) {
    const code = error instanceof AccountDeletionFailure ? error.code : "provider_cleanup_failed";
    await repository.fail(jobId, code);
    throw error;
  }
}

export class PostgresAccountDeletionRepository implements AccountDeletionRepository {
  constructor(private readonly pool: Pool) {}

  async begin(jobId: string, userId: string): Promise<boolean> {
    const result = await this.pool.query(
      `update public.moderation_jobs
          set status = 'processing', failure_code = null, updated_at = now()
        where id = $1
          and kind = 'account_deletion'
          and (subject_user_id = $2 or subject_user_id is null)
          and status in ('queued', 'processing', 'awaiting_external_cleanup', 'failed')
      returning id`,
      [jobId, userId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async resources(userId: string): Promise<AccountDeletionResources> {
    const [storage, mux, apple] = await Promise.all([
      this.pool.query<{ storage_path: string }>(
        `select storage_path from public.media_assets where owner_id = $1 order by storage_path`,
        [userId],
      ),
      this.pool.query<{ mux_asset_id: string }>(
        `select mux_asset_id
           from public.publications
          where owner_id = $1 and mux_asset_id is not null
          order by mux_asset_id`,
        [userId],
      ),
      this.pool.query<{ has_apple_identity: boolean }>(
        `select exists (
           select 1 from auth.identities where user_id = $1 and provider = 'apple'
         ) as has_apple_identity`,
        [userId],
      ),
    ]);
    return {
      storagePaths: storage.rows.map((row) => row.storage_path),
      muxAssetIds: mux.rows.map((row) => row.mux_asset_id),
      hasAppleIdentity: apple.rows[0]?.has_apple_identity ?? false,
    };
  }

  async complete(jobId: string): Promise<void> {
    await this.pool.query(
      `update public.moderation_jobs
          set status = 'completed', subject_user_id = null, failure_code = null, updated_at = now()
        where id = $1 and kind = 'account_deletion'`,
      [jobId],
    );
  }

  async fail(jobId: string, code: string): Promise<void> {
    await this.pool.query(
      `update public.moderation_jobs
          set status = 'failed', failure_code = $2, updated_at = now()
        where id = $1 and kind = 'account_deletion'`,
      [jobId, code.slice(0, 100)],
    );
  }
}

async function requireProviderSuccess(response: Response, code: string): Promise<void> {
  if (response.ok || response.status === 404) return;
  throw new AccountDeletionFailure(code, `Provider cleanup failed with status ${response.status}`);
}

export class SupabaseStorageDeletionProvider implements StorageDeletionProvider {
  constructor(
    private readonly supabaseURL: string,
    private readonly serviceRoleKey: string,
  ) {}

  async remove(paths: string[]): Promise<void> {
    for (let index = 0; index < paths.length; index += 100) {
      const prefixes = paths.slice(index, index + 100);
      const response = await fetch(`${this.supabaseURL}/storage/v1/object/private-drafts`, {
        method: "DELETE",
        headers: {
          apikey: this.serviceRoleKey,
          authorization: `Bearer ${this.serviceRoleKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ prefixes }),
      });
      await requireProviderSuccess(response, "storage_cleanup_failed");
    }
  }
}

export class SupabaseAuthDeletionProvider implements AuthDeletionProvider {
  constructor(
    private readonly supabaseURL: string,
    private readonly serviceRoleKey: string,
  ) {}

  async remove(userId: string): Promise<void> {
    const response = await fetch(
      `${this.supabaseURL}/auth/v1/admin/users/${encodeURIComponent(userId)}?should_soft_delete=false`,
      {
        method: "DELETE",
        headers: {
          apikey: this.serviceRoleKey,
          authorization: `Bearer ${this.serviceRoleKey}`,
        },
      },
    );
    await requireProviderSuccess(response, "auth_cleanup_failed");
  }
}

export class MuxAssetDeletionProvider implements MuxDeletionProvider {
  private readonly authorization: string;

  constructor(tokenId: string, tokenSecret: string) {
    this.authorization = `Basic ${Buffer.from(`${tokenId}:${tokenSecret}`).toString("base64")}`;
  }

  async remove(assetIds: string[]): Promise<void> {
    for (const assetId of assetIds) {
      const response = await fetch(`https://api.mux.com/video/v1/assets/${encodeURIComponent(assetId)}`, {
        method: "DELETE",
        headers: { authorization: this.authorization },
      });
      await requireProviderSuccess(response, "mux_cleanup_failed");
    }
  }
}
