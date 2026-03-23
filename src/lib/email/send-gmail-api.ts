import "server-only";
import { google } from "googleapis";

type GoogleApiLikeError = Error & {
  code?: number | string;
  status?: number;
  response?: {
    status?: number;
    data?: unknown;
  };
  errors?: unknown;
};

function getRequiredEnv(name: string) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function getSenderHeader() {
  const address = getRequiredEnv("GOOGLE_SENDER_EMAIL");
  const name = process.env.EMAIL_FROM_NAME?.trim();

  if (!name) {
    return address;
  }

  return `"${name}" <${address}>`;
}

export function toBase64Url(input: string) {
  return Buffer.from(input, "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function buildMimeMessage(input: {
  to: string;
  subject: string;
  text: string;
  html: string;
}) {
  const boundary = `portal-escarlate-${Date.now()}`;

  return [
    `From: ${getSenderHeader()}`,
    `To: ${input.to}`,
    `Subject: ${input.subject}`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    'Content-Type: text/plain; charset="UTF-8"',
    "Content-Transfer-Encoding: 7bit",
    "",
    input.text,
    "",
    `--${boundary}`,
    'Content-Type: text/html; charset="UTF-8"',
    "Content-Transfer-Encoding: 7bit",
    "",
    input.html,
    "",
    `--${boundary}--`,
    "",
  ].join("\r\n");
}

function getOAuthClient() {
  const client = new google.auth.OAuth2(
    getRequiredEnv("GOOGLE_CLIENT_ID"),
    getRequiredEnv("GOOGLE_CLIENT_SECRET"),
  );

  client.setCredentials({
    refresh_token: getRequiredEnv("GOOGLE_REFRESH_TOKEN"),
  });

  return client;
}

export async function sendGmailApiEmail(input: {
  to: string;
  subject: string;
  text: string;
  html: string;
}) {
  const auth = getOAuthClient();
  const gmail = google.gmail({
    version: "v1",
    auth,
  });

  const raw = toBase64Url(buildMimeMessage(input));

  try {
    await gmail.users.messages.send({
      userId: "me",
      requestBody: {
        raw,
      },
    });
  } catch (error) {
    if (error instanceof Error) {
      const googleError = error as GoogleApiLikeError;

      console.error("Gmail API send failed", {
        name: googleError.name,
        message: googleError.message,
        code: googleError.code,
        status: googleError.status ?? googleError.response?.status,
        responseData: googleError.response?.data,
        errors: googleError.errors,
      });

      throw new Error(
        `Failed to send email through Gmail API: ${googleError.message}`,
      );
    } else {
      console.error("Gmail API send failed");
      throw new Error("Failed to send email through Gmail API: unknown error");
    }
  }
}
