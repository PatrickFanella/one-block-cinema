import { redirect } from "next/navigation";
import { decidePublication } from "./actions";
import { createSupabaseServerClient } from "../lib/supabase/server";

export const dynamic = "force-dynamic";

interface QueueItem {
  id: string;
  status: string;
  created_at: string;
  publication_id: string | null;
  publications: { caption: string; owner_id: string; created_at: string } | null;
}

export default async function ModerationQueuePage() {
  const supabase = await createSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const role = auth.user?.app_metadata.role;
  if (!auth.user) redirect("/login");
  if (role !== "admin" && role !== "moderator") redirect("/unauthorized");

  const { data, error } = await supabase
    .from("moderation_jobs")
    .select("id,status,created_at,publication_id,publications(caption,owner_id,created_at)")
    .in("status", ["queued", "manual_review"])
    .order("created_at", { ascending: true })
    .limit(100);
  if (error) throw error;
  const items = (data ?? []) as unknown as QueueItem[];

  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">INTERNAL · ADMIN ONLY</p>
          <h1>Moderation queue</h1>
        </div>
        <p>{items.length} awaiting review</p>
      </header>

      <section className="queue" aria-label="Publications awaiting review">
        {items.length === 0 ? <p className="empty">The queue is clear.</p> : null}
        {items.map((item) => (
          <article key={item.id}>
            <div className="meta">
              <span>{item.status}</span>
              <time dateTime={item.created_at}>{new Date(item.created_at).toLocaleString("en-US")}</time>
            </div>
            <h2>{item.publications?.caption || "Untitled publication"}</h2>
            <p className="identifier">Publication {item.publication_id ?? "unavailable"}</p>
            {item.publication_id ? (
              <form action={decidePublication}>
                <input type="hidden" name="publicationId" value={item.publication_id} />
                <label>
                  Reason code
                  <input name="reasonCode" required maxLength={100} placeholder="policy-safe or policy-category" />
                </label>
                <div className="actions">
                  <button name="decision" value="approved" className="approve">Approve</button>
                  <button name="decision" value="rejected" className="reject">Reject</button>
                </div>
              </form>
            ) : null}
          </article>
        ))}
      </section>
    </main>
  );
}
