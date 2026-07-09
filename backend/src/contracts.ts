import { z } from "zod";

export const uuid = z.uuid();
export const idempotencyKey = z.uuid();

export const publicationInput = z.object({
  projectId: uuid,
  challengeId: uuid.optional(),
  visibility: z.enum(["private", "unlisted", "public"]),
  caption: z.string().trim().max(500).default(""),
  commentsEnabled: z.boolean().default(true),
});

export const uploadRequestInput = z.object({
  projectId: uuid,
  mediaAssetId: uuid,
  byteCount: z.number().int().positive().max(5_000_000_000),
  sha256: z.string().regex(/^[a-f0-9]{64}$/i),
  contentType: z.enum(["video/mp4", "video/quicktime"]),
});

export const challengeParams = z.object({ id: uuid });

export const commentInput = z.object({
  publicationId: uuid,
  body: z.string().trim().min(1).max(1_000),
  feedbackPromptId: z.string().trim().max(100).optional(),
});

export const commentParams = z.object({ id: uuid });

export const reportInput = z
  .object({
    publicationId: uuid.optional(),
    commentId: uuid.optional(),
    reason: z.enum([
      "harassment",
      "hate",
      "sexual_content",
      "violence",
      "self_harm",
      "privacy",
      "spam",
      "other",
    ]),
  })
  .refine((value) => Number(Boolean(value.publicationId)) + Number(Boolean(value.commentId)) === 1, {
    message: "Exactly one report target is required",
  });

export const blockInput = z.object({ userId: uuid });

export const critiqueInput = z.object({
  projectId: uuid,
  consentedAt: z.iso.datetime(),
});

export const muxWebhookInput = z.object({
  type: z.string().min(1).max(200),
  id: z.string().min(1).max(200),
  data: z.record(z.string(), z.unknown()),
});

export const errorResponse = z.object({
  error: z.string(),
  message: z.string(),
  requestId: z.string(),
});

export function parseIdempotencyHeader(value: string | string[] | undefined): string {
  const candidate = Array.isArray(value) ? value[0] : value;
  return idempotencyKey.parse(candidate);
}
