import { redirect } from "next/navigation";
import { auth } from "@/auth";
import { AuthPortal } from "@/components/auth/AuthPortal";

export default async function HomePage() {
  const session = await auth();

  if (session?.user) {
    redirect("/dashboard");
  }

  return <AuthPortal />;
}
