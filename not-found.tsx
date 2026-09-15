import Link from "next/link";
import { Card, Icon } from "@/components/ui";

export default function NotFound() {
  return (
    <div className="grid min-h-dvh place-items-center px-6">
      <Card className="grid-noise max-w-lg p-8 text-center">
        <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl border border-line bg-ink-soft text-2xl">
          🧭
        </span>
        <h1 className="mt-4 text-xl font-bold text-fg">Рынок не найден</h1>
        <p className="mt-2 text-sm text-muted">
          Такого актива нет в листинге. Вернитесь на список рынков и выберите доступную пару.
        </p>
        <Link
          href="/markets"
          className="mt-5 inline-flex items-center gap-2 rounded-lg bg-gold px-4 py-2.5 text-sm font-semibold text-black transition hover:bg-gold-soft"
        >
          <Icon name="markets" className="h-4 w-4" /> Ко всем рынкам
        </Link>
      </Card>
    </div>
  );
}
