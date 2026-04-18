import { redirect } from "next/navigation";
import { auth } from "@/auth";
import { AuthPortal } from "@/components/auth/AuthPortal";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ verified?: string }>;
}) {
  const session = await auth();

  if (session?.user) {
    redirect("/dashboard");
  }

  const params = await searchParams;

  return (
    <AuthPortal
      initialMode="login"
      loginNotice={
        params.verified === "1"
          ? "E-mail confirmado. Agora voce pode entrar no portal."
          : undefined
      }
    />
  );
}
