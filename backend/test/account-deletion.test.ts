import { afterEach, describe, expect, it, vi } from "vitest";
import {
  AccountDeletionFailure,
  executeAccountDeletion,
  MuxAssetDeletionProvider,
  SupabaseAuthDeletionProvider,
  SupabaseStorageDeletionProvider,
  type AccountDeletionProviders,
  type AccountDeletionRepository,
  type AccountDeletionResources,
} from "../src/account-deletion.js";

afterEach(() => vi.unstubAllGlobals());

class FakeRepository implements AccountDeletionRepository {
  completed = false;
  failedCode: string | null = null;

  constructor(
    private readonly shouldRun: boolean,
    private readonly value: AccountDeletionResources,
  ) {}

  async begin(): Promise<boolean> {
    return this.shouldRun;
  }

  async resources(): Promise<AccountDeletionResources> {
    return this.value;
  }

  async complete(): Promise<void> {
    this.completed = true;
  }

  async fail(_jobId: string, code: string): Promise<void> {
    this.failedCode = code;
  }
}

function providers(events: string[]): AccountDeletionProviders {
  return {
    apple: { revoke: async () => { events.push("apple"); } },
    storage: { remove: async (paths) => { events.push(`storage:${paths.join(",")}`); } },
    mux: { remove: async (ids) => { events.push(`mux:${ids.join(",")}`); } },
    auth: { remove: async () => { events.push("auth"); } },
  };
}

describe("account deletion", () => {
  it("removes provider data before deleting Auth and completes the durable job", async () => {
    const events: string[] = [];
    const repository = new FakeRepository(true, {
      storagePaths: ["user/project/clip.mov"],
      muxAssetIds: ["asset-1"],
      hasAppleIdentity: true,
    });

    await expect(
      executeAccountDeletion("job", "user", repository, providers(events)),
    ).resolves.toBe("completed");

    expect(events).toEqual(["apple", "storage:user/project/clip.mov", "mux:asset-1", "auth"]);
    expect(repository.completed).toBe(true);
    expect(repository.failedCode).toBeNull();
  });

  it("fails closed before destructive cleanup when Apple revocation is unavailable", async () => {
    const repository = new FakeRepository(true, {
      storagePaths: ["clip.mov"],
      muxAssetIds: [],
      hasAppleIdentity: true,
    });
    const configured = providers([]);
    configured.apple = null;

    await expect(
      executeAccountDeletion("job", "user", repository, configured),
    ).rejects.toEqual(
      new AccountDeletionFailure(
        "apple_revocation_unconfigured",
        "Sign in with Apple revocation is not configured",
      ),
    );
    expect(repository.failedCode).toBe("apple_revocation_unconfigured");
    expect(repository.completed).toBe(false);
  });

  it("treats an already completed durable job as an idempotent success", async () => {
    const repository = new FakeRepository(false, {
      storagePaths: [],
      muxAssetIds: [],
      hasAppleIdentity: false,
    });
    const unavailable: AccountDeletionProviders = {
      storage: null,
      mux: null,
      auth: null,
      apple: null,
    };

    await expect(
      executeAccountDeletion("job", "user", repository, unavailable),
    ).resolves.toBe("already_completed");
  });

  it("batches Storage cleanup and treats missing provider resources as deleted", async () => {
    const calls: Array<{ url: string; init: RequestInit | undefined }> = [];
    vi.stubGlobal("fetch", async (input: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: input.toString(), init });
      return new Response(null, { status: 404 });
    });
    const paths = Array.from({ length: 101 }, (_, index) => `user/file-${index}.mov`);

    await new SupabaseStorageDeletionProvider("https://example.supabase.co", "service-key").remove(paths);
    await new MuxAssetDeletionProvider("mux-id", "mux-secret").remove(["asset-id"]);
    await new SupabaseAuthDeletionProvider("https://example.supabase.co", "service-key").remove("user-id");

    expect(calls).toHaveLength(4);
    expect(JSON.parse(calls[0]?.init?.body as string).prefixes).toHaveLength(100);
    expect(JSON.parse(calls[1]?.init?.body as string).prefixes).toHaveLength(1);
    expect(calls[2]?.url).toContain("api.mux.com/video/v1/assets/asset-id");
    expect(calls[3]?.url).toContain("/auth/v1/admin/users/user-id");
  });
});
