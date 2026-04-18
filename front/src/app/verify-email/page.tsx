import Link from "next/link";
import { redirect } from "next/navigation";
import { verifyPendingEmailToken } from "@/lib/auth/email-verification";
import styles from "./verify-email.module.css";

export default async function VerifyEmailPage({
  searchParams,
}: {
  searchParams: Promise<{ code?: string }>;
}) {
  const params = await searchParams;
  const code = params.code?.trim();

  if (code) {
    const result = await verifyPendingEmailToken(code);

    if (result.ok) {
      redirect("/login?verified=1");
    }
  }

  return (
    <main className={styles.page}>
      <section className={styles.panel}>
        <span className={styles.kicker}>Verificacao de e-mail</span>
        <h1 className={styles.title}>Codigo expirado ou invalido</h1>
        <p className={styles.copy}>
          Este link nao pode mais ser usado. Solicite um novo cadastro para
          receber outro e-mail de confirmacao.
        </p>
        <Link className={styles.action} href="/login">
          Voltar para login
        </Link>
      </section>
    </main>
  );
}
