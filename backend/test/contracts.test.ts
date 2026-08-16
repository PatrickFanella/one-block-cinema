import { describe, expect, it } from "vitest";
import {
  commentInput,
  critiqueInput,
  parseIdempotencyHeader,
  publicationInput,
  reportInput,
  uploadRequestInput,
} from "../src/contracts.js";
import { verifyMuxSignature } from "../src/webhook.js";
import { createHmac } from "node:crypto";

const id = "550e8400-e29b-41d4-a716-446655440000";

describe("API contracts", () => {
  it("requires a UUID idempotency key", () => {
    expect(parseIdempotencyHeader(id)).toBe(id);
    expect(() => parseIdempotencyHeader(undefined)).toThrow();
    expect(() => parseIdempotencyHeader("retry-me")).toThrow();
  });

  it("validates publication and comment limits", () => {
    expect(
      publicationInput.parse({ projectId: id, visibility: "public" }).commentsEnabled,
    ).toBe(true);
    expect(() => commentInput.parse({ publicationId: id, body: "" })).toThrow();
    expect(() => commentInput.parse({ publicationId: id, body: "x".repeat(1_001) })).toThrow();
  });

  it("requires exactly one report target", () => {
    expect(reportInput.parse({ publicationId: id, reason: "spam" }).publicationId).toBe(id);
    expect(() => reportInput.parse({ reason: "spam" })).toThrow();
    expect(() => reportInput.parse({ publicationId: id, commentId: id, reason: "spam" })).toThrow();
  });

  it("caps upload size and accepts explicit critique consent", () => {
    expect(
      uploadRequestInput.parse({
        projectId: id,
        mediaAssetId: id,
        byteCount: 10,
        sha256: "a".repeat(64),
        contentType: "video/mp4",
      }).byteCount,
    ).toBe(10);
    expect(
      critiqueInput.parse({ projectId: id, consentedAt: "2026-07-09T12:00:00.000Z" }).projectId,
    ).toBe(id);
  });
});

describe("Mux webhook verification", () => {
  it("accepts a fresh matching signature and rejects stale signatures", () => {
    const secret = "test-secret";
    const timestamp = 1_700_000_000;
    const body = Buffer.from('{"type":"video.asset.ready"}');
    const digest = createHmac("sha256", secret)
      .update(`${timestamp}.`)
      .update(body)
      .digest("hex");
    const header = `t=${timestamp},v1=${digest}`;

    expect(verifyMuxSignature(body, header, secret, timestamp)).toBe(true);
    expect(verifyMuxSignature(body, header, secret, timestamp + 301)).toBe(false);
  });
});
