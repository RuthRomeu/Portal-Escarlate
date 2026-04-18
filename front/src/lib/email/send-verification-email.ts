import "server-only";
import { sendGmailApiEmail } from "@/lib/email/send-gmail-api";

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function buildVerificationEmailHtml(verificationUrl: string) {
  const safeUrl = escapeHtml(verificationUrl);

  return `
    <div style="margin:0;padding:32px 16px;background:#f6f1e8;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-collapse:collapse;width:100%;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-collapse:separate;width:100%;max-width:640px;background:#fffaf4;border:1px solid #e8d3a1;border-radius:28px;box-shadow:0 24px 70px rgba(76,15,20,0.16);overflow:hidden;">
              <tr>
                <td style="padding:0;background:
                  radial-gradient(circle at top left, rgba(198,49,61,0.28), transparent 34%),
                  radial-gradient(circle at top right, rgba(206,169,84,0.26), transparent 28%),
                  linear-gradient(135deg, #3f0910 0%, #5d0e17 55%, #7b1621 100%);">
                  <div style="height:8px;background:linear-gradient(90deg,#f5e4b2 0%,#c8942f 26%,#f9e7bd 52%,#b57a1a 78%,#f4ddb0 100%);"></div>
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-collapse:collapse;">
                    <tr>
                      <td style="padding:34px 38px 28px;">
                        <div style="display:inline-block;padding:10px 16px;border:1px solid rgba(248,224,171,0.35);border-radius:999px;background:rgba(255,255,255,0.08);color:#f6dfab;font-family:Georgia,'Times New Roman',serif;font-size:12px;letter-spacing:0.32em;text-transform:uppercase;">
                          Portal Escarlate
                        </div>
                        <div style="margin-top:24px;width:74px;height:74px;border-radius:22px;border:1px solid rgba(246,223,171,0.32);background:linear-gradient(145deg, rgba(248,224,171,0.22), rgba(255,255,255,0.08));text-align:center;line-height:74px;color:#f8e0ab;font-family:Georgia,'Times New Roman',serif;font-size:34px;font-weight:700;box-shadow:0 16px 34px rgba(0,0,0,0.18);">
                          S
                        </div>
                        <p style="margin:28px 0 0;color:#f2dba9;font-size:12px;letter-spacing:0.28em;text-transform:uppercase;font-family:'Segoe UI',Arial,sans-serif;">
                          Confirmacao de acesso reservado
                        </p>
                        <h1 style="margin:14px 0 0;color:#fff6e2;font-family:Georgia,'Times New Roman',serif;font-size:40px;line-height:1.06;font-weight:700;">
                          Confirme seu e-mail
                        </h1>
                        <p style="margin:16px 0 0;color:rgba(255,241,214,0.82);font-size:16px;line-height:1.85;font-family:'Segoe UI',Arial,sans-serif;max-width:470px;">
                          Seu acesso ao ambiente reservado do Portal Escarlate está quase pronto. Para concluir o cadastro e liberar sua entrada, confirme o endereço de e-mail usando o botão abaixo.
                        </p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <tr>
                <td style="padding:34px 38px 16px;background:#fffaf4;">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-collapse:collapse;">
                    <tr>
                      <td>
                        <div style="padding:20px 22px;border:1px solid #efd9a8;border-radius:20px;background:linear-gradient(180deg,#fff8ec 0%,#fff3de 100%);box-shadow:inset 0 1px 0 rgba(255,255,255,0.8);">
                          <p style="margin:0;color:#6a1a22;font-family:'Segoe UI',Arial,sans-serif;font-size:14px;letter-spacing:0.18em;text-transform:uppercase;">
                            Seguranca de verificacao
                          </p>
                          <p style="margin:12px 0 0;color:#372126;font-family:'Segoe UI',Arial,sans-serif;font-size:16px;line-height:1.8;">
                            Este link expira em <strong style="color:#8d1320;">5 minutos</strong> e deve ser usado uma única vez.
                          </p>
                        </div>
                      </td>
                    </tr>

                    <tr>
                      <td align="center" style="padding:30px 0 24px;">
                        <a href="${safeUrl}" style="display:inline-block;padding:18px 34px;border-radius:18px;background:linear-gradient(135deg,#7e0f1b 0%,#b01f2d 62%,#7a101a 100%);border:1px solid #d6ab58;box-shadow:0 18px 34px rgba(122,16,26,0.22), inset 0 1px 0 rgba(255,234,202,0.34);color:#fff7e8;text-decoration:none;font-family:'Segoe UI',Arial,sans-serif;font-size:16px;font-weight:700;letter-spacing:0.08em;">
                          Confirmar e-mail
                        </a>
                      </td>
                    </tr>

                    <tr>
                      <td>
                        <div style="padding:22px 22px 18px;border-radius:20px;background:#fff;border:1px solid #f0dfba;">
                          <p style="margin:0 0 10px;color:#7a1320;font-family:'Segoe UI',Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;">
                            Se o botão não abrir
                          </p>
                          <p style="margin:0;color:#514245;font-family:'Segoe UI',Arial,sans-serif;font-size:14px;line-height:1.8;">
                            Copie e cole este link no navegador:
                          </p>
                          <p style="margin:12px 0 0;word-break:break-word;">
                            <a href="${safeUrl}" style="color:#8d1320;font-family:'Segoe UI',Arial,sans-serif;font-size:14px;line-height:1.7;text-decoration:underline;">
                              ${safeUrl}
                            </a>
                          </p>
                        </div>
                      </td>
                    </tr>

                    <tr>
                      <td style="padding-top:28px;">
                        <div style="height:1px;background:linear-gradient(90deg,rgba(214,171,88,0) 0%,rgba(214,171,88,0.9) 50%,rgba(214,171,88,0) 100%);"></div>
                      </td>
                    </tr>

                    <tr>
                      <td style="padding:24px 4px 10px;">
                        <p style="margin:0;color:#5b4a4d;font-family:'Segoe UI',Arial,sans-serif;font-size:14px;line-height:1.8;">
                          Se você não solicitou este cadastro, ignore esta mensagem. Nenhuma ação será realizada sem a confirmação do link.
                        </p>
                        <p style="margin:18px 0 0;color:#8b7a65;font-family:'Segoe UI',Arial,sans-serif;font-size:12px;line-height:1.8;letter-spacing:0.12em;text-transform:uppercase;">
                          Curadoria reservada • poder sob análise • acesso verificado
                        </p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </div>
  `;
}

function buildVerificationEmailText(verificationUrl: string) {
  return [
    "PORTAL ESCARLATE",
    "",
    "Confirme seu e-mail para concluir seu cadastro.",
    "",
    "Seu acesso ao ambiente reservado está quase pronto. Abra o link abaixo em até 5 minutos:",
    verificationUrl,
    "",
    "Se você não solicitou este cadastro, ignore esta mensagem.",
  ].join("\n");
}

export async function sendVerificationEmail(input: {
  to: string;
  verificationUrl: string;
}) {
  await sendGmailApiEmail({
    to: input.to,
    subject: "Confirme seu e-mail para concluir seu cadastro",
    text: buildVerificationEmailText(input.verificationUrl),
    html: buildVerificationEmailHtml(input.verificationUrl),
  });
}
