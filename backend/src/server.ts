import { Pool } from "pg";
import { buildApp } from "./app.js";
import { createSupabaseAuthenticator } from "./auth.js";
import { loadConfig } from "./config.js";
import { PgBossJobQueue, startBoss } from "./jobs.js";
import { PostgresApiStore } from "./repository.js";

const config = loadConfig();
const pool = new Pool({ connectionString: config.DATABASE_URL, max: 10 });
const boss = await startBoss(config.DATABASE_URL);
const app = await buildApp({
  config,
  store: new PostgresApiStore(pool),
  jobs: new PgBossJobQueue(boss),
  authenticate: createSupabaseAuthenticator(config.SUPABASE_URL),
});

app.addHook("onClose", async () => {
  await boss.stop({ graceful: true });
  await pool.end();
});

await app.listen({ host: config.HOST, port: config.PORT });
