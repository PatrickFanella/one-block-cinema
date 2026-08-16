import { createRemoteJWKSet, jwtVerify } from "jose";
import type { FastifyRequest } from "fastify";

export interface AuthUser {
  id: string;
  role: string;
  isAdmin: boolean;
}

export type Authenticate = (request: FastifyRequest) => Promise<AuthUser>;

export function createSupabaseAuthenticator(supabaseUrl: string): Authenticate {
  const issuer = `${supabaseUrl.replace(/\/$/, "")}/auth/v1`;
  const jwks = createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`));

  return async (request) => {
    const header = request.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw Object.assign(new Error("Authentication is required"), { statusCode: 401 });
    }

    const token = header.slice("Bearer ".length);
    const { payload } = await jwtVerify(token, jwks, {
      issuer,
      audience: "authenticated",
    });
    if (!payload.sub) {
      throw Object.assign(new Error("The access token has no subject"), { statusCode: 401 });
    }
    const appMetadata = (payload.app_metadata ?? {}) as Record<string, unknown>;
    const role = typeof appMetadata.role === "string" ? appMetadata.role : "creator";
    return {
      id: payload.sub,
      role,
      isAdmin: role === "admin" || role === "moderator",
    };
  };
}
