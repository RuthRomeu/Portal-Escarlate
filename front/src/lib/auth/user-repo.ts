import "server-only";
import {
  SupabaseApiError,
  type LegacyUserRow,
  supabaseAdminRequest,
} from "@/lib/supabase/server";

type PublicUserRow = Pick<LegacyUserRow, "id" | "email" | "created_at">;
type AuthUserRow = Pick<LegacyUserRow, "id" | "email" | "password" | "created_at">;

export type SessionUser = {
  id: string;
  email: string;
  role: string;
};

export class DuplicateEmailError extends Error {
  constructor() {
    super("Já existe uma conta com esse e-mail.");
    this.name = "DuplicateEmailError";
  }
}

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

async function findFirstByEmail<T>(select: string, email: string) {
  const normalizedEmail = normalizeEmail(email);
  const query = new URLSearchParams({
    select,
    email: `eq.${normalizedEmail}`,
    limit: "1",
  });

  const rows = await supabaseAdminRequest<T[]>(
    `users?${query.toString()}`,
    { method: "GET" },
  );

  return rows[0] ?? null;
}

export async function findUserByEmailForAuth(email: string) {
  try {
    return await findFirstByEmail<AuthUserRow>("id,email,password,created_at", email);
  } catch (error) {
    if (error instanceof SupabaseApiError) {
      throw new Error(`Failed to fetch user for auth: ${error.message}`);
    }

    throw error;
  }
}

export async function findUserByEmail(email: string) {
  try {
    return await findFirstByEmail<PublicUserRow>("id,email,created_at", email);
  } catch (error) {
    if (error instanceof SupabaseApiError) {
      throw new Error(`Failed to fetch public user data: ${error.message}`);
    }

    throw error;
  }
}

export async function createUser(input: {
  email: string;
  passwordHash: string;
}) {
  try {
    const rows = await supabaseAdminRequest<PublicUserRow[]>(
      "users?select=id,email,created_at",
      {
        method: "POST",
        headers: {
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          email: normalizeEmail(input.email),
          password: input.passwordHash,
        }),
      },
    );

    return rows[0] ?? null;
  } catch (error) {
    if (error instanceof SupabaseApiError && error.code === "23505") {
      throw new DuplicateEmailError();
    }

    if (error instanceof SupabaseApiError) {
      throw new Error(`Failed to create user: ${error.message}`);
    }

    throw error;
  }
}

export function toSessionUser(user: { id: string; email: string }): SessionUser {
  return {
    id: user.id,
    email: normalizeEmail(user.email),
    role: "user",
  };
}
