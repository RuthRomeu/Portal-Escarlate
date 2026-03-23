import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Portal Escarlate",
  description:
    "Curadoria reservada de notícias de alto impacto e apoio à pesquisa em arquivos públicos.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
