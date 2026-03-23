import { google } from "googleapis";

function getRequiredEnv(name) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function toBase64Url(input) {
  return Buffer.from(input, "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function buildMimeMessage({ to, subject, text, html }) {
  const fromName = process.env.EMAIL_FROM_NAME?.trim();
  const fromAddress = getRequiredEnv("GOOGLE_SENDER_EMAIL");
  const from = fromName ? `"${fromName}" <${fromAddress}>` : fromAddress;
  const boundary = `portal-escarlate-${Date.now()}`;

  return [
    `From: ${from}`,
    `To: ${to}`,
    `Subject: ${subject}`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    'Content-Type: text/plain; charset="UTF-8"',
    "",
    text,
    "",
    `--${boundary}`,
    'Content-Type: text/html; charset="UTF-8"',
    "",
    html,
    "",
    `--${boundary}--`,
    "",
  ].join("\r\n");
}

async function main() {
  const to = process.argv[2] || process.env.EMAIL_TEST_TO;

  if (!to) {
    throw new Error("Provide a destination e-mail as argv[2] or EMAIL_TEST_TO.");
  }

  const auth = new google.auth.OAuth2(
    getRequiredEnv("GOOGLE_CLIENT_ID"),
    getRequiredEnv("GOOGLE_CLIENT_SECRET"),
  );

  auth.setCredentials({
    refresh_token: getRequiredEnv("GOOGLE_REFRESH_TOKEN"),
  });

  const gmail = google.gmail({ version: "v1", auth });
  const raw = toBase64Url(
    buildMimeMessage({
      to,
      subject: "Teste Gmail API",
      text: "Teste simples do envio via Gmail API.",
      html: "<p>Teste simples do envio via <strong>Gmail API</strong>.</p>",
    }),
  );

  await gmail.users.messages.send({
    userId: "me",
    requestBody: { raw },
  });

  console.log(`Test email sent to ${to}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
