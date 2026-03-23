import "server-only";
import { sendGmailApiEmail } from "@/lib/email/send-gmail-api";

export async function sendTestEmail(to: string) {
  await sendGmailApiEmail({
    to,
    subject: "Teste de envio Gmail API",
    text: "Este e-mail confirma que o envio via Gmail API esta funcionando.",
    html: "<p>Este e-mail confirma que o envio via Gmail API esta funcionando.</p>",
  });
}
