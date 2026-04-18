import { NextResponse } from "next/server";
import { sendTestEmail } from "@/lib/email/send-test-email";

export const runtime = "nodejs";

export async function POST(request: Request) {
  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return NextResponse.json(
      { message: "Nao foi possivel ler os dados do teste." },
      { status: 400 },
    );
  }

  const to =
    typeof payload === "object" &&
    payload !== null &&
    "to" in payload &&
    typeof payload.to === "string"
      ? payload.to.trim()
      : "";

  if (!to) {
    return NextResponse.json(
      { message: "Informe um destinatario em `to`." },
      { status: 400 },
    );
  }

  try {
    await sendTestEmail(to);

    return NextResponse.json(
      { message: "E-mail de teste enviado com Gmail API." },
      { status: 200 },
    );
  } catch (error) {
    return NextResponse.json(
      {
        message:
          error instanceof Error
            ? error.message
            : "Falha ao enviar e-mail de teste com Gmail API.",
      },
      { status: 500 },
    );
  }
}
