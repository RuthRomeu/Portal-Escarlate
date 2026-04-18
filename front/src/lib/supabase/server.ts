import "server-only";

function getRequiredEnv(name: string) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function getSupabaseUrl() {
  const value = getRequiredEnv("NEXT_PUBLIC_SUPABASE_URL");

  if (value.includes("your-project-id.supabase.co")) {
    throw new Error(
      "Supabase configuration error: NEXT_PUBLIC_SUPABASE_URL is still using the placeholder value.",
    );
  }

  try {
    const url = new URL(value);

    if (!url.protocol.startsWith("http")) {
      throw new Error("Invalid protocol.");
    }
  } catch {
    throw new Error(
      "Supabase configuration error: NEXT_PUBLIC_SUPABASE_URL is not a valid URL.",
    );
  }

  return value;
}

function getSupabaseServiceRoleKey() {
  const value = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");

  if (value === "your-server-only-service-role-key") {
    throw new Error(
      "Supabase configuration error: SUPABASE_SERVICE_ROLE_KEY is still using the placeholder value.",
    );
  }

  return value;
}

export type LegacyUserRow = {
  id: string;
  email: string;
  password: string;
  created_at: string | null;
};

type SupabaseErrorPayload = {
  code?: string;
  details?: string;
  hint?: string;
  message: string;
};

export class SupabaseApiError extends Error {
  code?: string;
  status: number;

  constructor(status: number, payload: SupabaseErrorPayload | string) {
    super(typeof payload === "string" ? payload : payload.message);
    this.name = "SupabaseApiError";
    this.status = status;
    this.code = typeof payload === "string" ? undefined : payload.code;
  }
}

function buildRestUrl(path: string) {
  return `${getSupabaseUrl()}/rest/v1/${path}`;
}

function buildAdminHeaders(extra?: HeadersInit): HeadersInit {
  const serviceRoleKey = getSupabaseServiceRoleKey();

  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

export async function supabaseAdminRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  let response: Response;

  try {
    response = await fetch(buildRestUrl(path), {
      ...init,
      headers: buildAdminHeaders(init.headers),
      cache: "no-store",
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unknown fetch failure";

    throw new Error(`Supabase API request failed: ${message}`);
  }

  if (!response.ok) {
    const text = await response.text();

    try {
      throw new SupabaseApiError(
        response.status,
        JSON.parse(text) as SupabaseErrorPayload,
      );
    } catch (error) {
      if (error instanceof SupabaseApiError) {
        throw error;
      }

      throw new SupabaseApiError(response.status, text);
    }
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}
