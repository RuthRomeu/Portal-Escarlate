import { NextResponse } from "next/server";
import { requestEmailVerification } from "@/lib/auth/email-verification";
import { flattenFieldErrors, registerSchema } from "@/lib/auth/validation";

export const runtime = "nodejs";

function getClientIp(request: Request) {
  const forwarded = request.headers.get("x-forwarded-for");

  if (forwarded) {
    return forwarded.split(",")[0]?.trim() || "unknown";
  }

  return request.headers.get("x-real-ip")?.trim() || "unknown";
}

export async function POST(request: Request) {
  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Nao foi possivel ler os dados do cadastro." },
      { status: 400 },
    );
  }

  const parsed = registerSchema.safeParse(payload);

  if (!parsed.success) {
    return NextResponse.json(
      {
        message: parsed.error.issues[0]?.message ?? "Revise os campos informados.",
        fieldErrors: flattenFieldErrors(parsed.error),
      },
      { status: 400 },
    );
  }

  try {
    const result = await requestEmailVerification({
      email: parsed.data.email,
      password: parsed.data.password,
      ip: getClientIp(request),
    });

    return NextResponse.json(
      { message: result.message },
      { status: result.status },
    );
  } catch (error) {
    console.error("Register request route failed", error);

    return NextResponse.json(
      {
        message:
          error instanceof Error
            ? error.message
            : "Nao foi possivel iniciar a verificacao por e-mail agora.",
      },
      { status: 500 },
    );
  }
}
