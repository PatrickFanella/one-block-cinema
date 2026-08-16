import { PgBoss } from "pg-boss";

export const queueNames = {
  moderatePublication: "moderate-publication",
  muxWebhook: "mux-webhook",
  deleteAccount: "delete-account",
  critique: "critique",
} as const;

export interface JobQueue {
  send(name: (typeof queueNames)[keyof typeof queueNames], data: object, singletonKey: string): Promise<string>;
}

export class PgBossJobQueue implements JobQueue {
  constructor(private readonly boss: PgBoss) {}

  async send(
    name: (typeof queueNames)[keyof typeof queueNames],
    data: object,
    singletonKey: string,
  ): Promise<string> {
    const id = await this.boss.send(name, data, { singletonKey, retryLimit: 8, retryBackoff: true });
    if (!id) throw new Error(`Failed to queue ${name}`);
    return id;
  }
}

export async function startBoss(databaseUrl: string): Promise<PgBoss> {
  const boss = new PgBoss({ connectionString: databaseUrl, application_name: "one-block-cinema" });
  boss.on("error", (error) => console.error("pg-boss error", error));
  await boss.start();
  for (const name of Object.values(queueNames)) {
    await boss.createQueue(name);
  }
  return boss;
}
