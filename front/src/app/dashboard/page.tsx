import { redirect } from "next/navigation";
import { auth } from "@/auth";
import { signOutAction } from "@/app/dashboard/actions";
import styles from "./dashboard.module.css";

export default async function DashboardPage() {
  const session = await auth();

  if (!session?.user) {
    redirect("/");
  }

  return (
    <main className={styles.page}>
      <section className={styles.panel}>
        <div className={styles.header}>
          <div>
            <span className={styles.kicker}>Ala reservada</span>
            <h1 className={styles.title}>Portal Escarlate</h1>
          </div>

          <form action={signOutAction}>
            <button className={styles.action} type="submit">
              Sair
            </button>
          </form>
        </div>

        <div className={styles.grid}>
          <article className={styles.card}>
            <span className={styles.label}>Conta ativa</span>
            <strong className={styles.value}>{session.user.email}</strong>
            <p className={styles.copy}>
              Sessao autenticada com JWT via Auth.js, usando a tabela `users`
              no Supabase apenas pelo servidor.
            </p>
          </article>

          <article className={styles.card}>
            <span className={styles.label}>Perfil</span>
            <strong className={styles.value}>{session.user.role}</strong>
            <p className={styles.copy}>
              O fluxo de entrada ja esta pronto para evoluir a autorizacao por
              papel sem expor dados sensiveis ao cliente.
            </p>
          </article>

          <article className={styles.cardWide}>
            <span className={styles.label}>Proxima etapa</span>
            <strong className={styles.value}>Curadoria e pesquisa documental</strong>
            <p className={styles.copy}>
              A home publica agora direciona o acesso. Daqui em diante, o passo
              natural e conectar a area editorial, os filtros de noticias e a
              pesquisa em arquivos publicos sobre contratos, votacoes, diarios
              oficiais e rastros relevantes de poder.
            </p>
          </article>
        </div>
      </section>
    </main>
  );
}
