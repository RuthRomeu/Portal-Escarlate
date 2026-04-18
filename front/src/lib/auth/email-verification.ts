import "server-only";
import { randomBytes } from "node:crypto";
import { hashPassword } from "@/lib/auth/password";
import { consumeRegisterRateLimit } from "@/lib/auth/register-rate-limit";
import {
  consumePendingRegistration,
  hashVerificationToken,
  removePendingRegistrationByEmail,
  upsertPendingRegistration,
} from "@/lib/auth/pending-email-verification-cache";
import { createUser, findUserByEmail, normalizeEmail } from "@/lib/auth/user-repo";

function getRequiredEnv(name: string) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function buildVerificationUrl(token: string) {
  const appUrl = getRequiredEnv("APP_URL").replace(/\/+$/, "");
  return `${appUrl}/verify-email?code=${encodeURIComponent(token)}`;
}

function generateVerificationToken() {
  return randomBytes(32).toString("base64url");
}

export async function requestEmailVerification(input: {
  email: string;
  password: string;
  ip: string;
}) {
  const email = normalizeEmail(input.email);
  const allowed = consumeRegisterRateLimit({
    email,
    ip: input.ip,
  });

  if (!allowed) {
    return {
      ok: false as const,
      status: 429,
      message: "Muitas tentativas de cadastro. Tente novamente em instantes.",
    };
  }

  const existingUser = await findUserByEmail(email);

  if (existingUser) {
    return {
      ok: false as const,
      status: 409,
      message:
        "Ja existe uma conta com este e-mail. Use o login para entrar no portal.",
    };
  }

  const passwordHash = await hashPassword(input.password);
  const token = generateVerificationToken();
  const tokenHash = hashVerificationToken(token);

  upsertPendingRegistration({
    email,
    passwordHash,
    tokenHash,
  });

  try {
    const { sendVerificationEmail } = await import(
      "@/lib/email/send-verification-email"
    );

    await sendVerificationEmail({
      to: email,
      verificationUrl: buildVerificationUrl(token),
    });
  } catch (error) {
    removePendingRegistrationByEmail(email);
    throw error;
  }

  return {
    ok: true as const,
    status: 200,
    message:
      "Se este e-mail puder receber acesso, enviaremos um link de confirmacao em instantes.",
  };
}

export async function verifyPendingEmailToken(code: string) {
  const pending = consumePendingRegistration(code);

  if (!pending) {
    return { ok: false as const };
  }

  const existingUser = await findUserByEmail(pending.email);

  if (!existingUser) {
    await createUser({
      email: pending.email,
      passwordHash: pending.passwordHash,
    });
  }

  return { ok: true as const };
}
