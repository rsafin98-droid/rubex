import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "RUBEX — персональная криптобиржа",
  description:
    "Личная спот-биржа с балансом 550 000 ₽: торги, ордера, кошелёк, депозиты и выводы в рублях.",
};

export const viewport: Viewport = {
  themeColor: "#0a0c10",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ru">
      <body className="bg-ink text-fg antialiased">{children}</body>
    </html>
  );
}
