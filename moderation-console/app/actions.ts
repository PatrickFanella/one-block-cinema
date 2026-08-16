"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createSupabaseServerClient } from "../lib/supabase/server";

const decisionSchema = z.object({
  publicationId: z.uuid(),
  decision: z.enum(["approved", "rejected"]),
  reasonCode: z.string().trim().min(1).max(100),
});

async function requireAdmin() {
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getUser();
  const role = data.user?.app_metadata.role;
  if (!data.user || (role !== "admin" && role !== "moderator")) redirect("/login");
  return { supabase, user: data.user };
}

export async function decidePublication(formData: FormData): Promise<void> {
  const input = decisionSchema.parse(Object.fromEntries(formData));
  const { supabase, user } = await requireAdmin();
  const { error: publicationError } = await supabase
    .from("publications")
    .update({ moderation_status: input.decision })
    .eq("id", input.publicationId);
  if (publicationError) throw publicationError;

  const { error: actionError } = await supabase.from("moderation_actions").insert({
    moderator_id: user.id,
    publication_id: input.publicationId,
    action: input.decision,
    reason_code: input.reasonCode,
  });
  if (actionError) throw actionError;
  revalidatePath("/");
}
