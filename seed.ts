import { db } from "@/db";
import {
  users,
  coins,
  holdings,
  orders,
  transactions,
  watchlist,
} from "@/db/schema";
import { COIN_SEEDS } from "@/lib/coins";
import { hashPassword } from "@/lib/auth";
import { eq } from "drizzle-orm";

let seeded = false;

/**
 * Idempotently ensures coins exist and the demo account is populated.
 */
export async function ensureSeed() {
  if (seeded) return;

  // Seed coins if empty
  const existingCoins = await db.select({ id: coins.id }).from(coins).limit(1);
  if (existingCoins.length === 0) {
    await db.insert(coins).values(
      COIN_SEEDS.map((c) => ({
        symbol: c.symbol,
        name: c.name,
        priceRub: c.priceRub.toFixed(2),
        change24h: c.change24h.toFixed(2),
        volume24h: c.volume24h.toFixed(2),
        marketCap: c.marketCap.toFixed(2),
        color: c.color,
        rank: c.rank,
      }))
    );
  }

  // Seed demo user + portfolio
  const existingUser = await db
    .select()
    .from(users)
    .where(eq(users.username, "me"))
    .limit(1);

  if (existingUser.length === 0) {
    const [user] = await db
      .insert(users)
      .values({
        username: "me",
        passwordHash: hashPassword("birzha"),
        displayName: "Мой аккаунт",
        cashBalance: "550000.00",
      })
      .returning();

    const price = (sym: string) =>
      COIN_SEEDS.find((c) => c.symbol === sym)!.priceRub;

    // Demo holdings (bought with a portion of a larger initial deposit)
    const demoHoldings = [
      { symbol: "BTC", amount: 0.025, avg: 8600000 },
      { symbol: "ETH", amount: 0.85, avg: 292000 },
      { symbol: "SOL", amount: 12, avg: 15200 },
      { symbol: "TON", amount: 150, avg: 505 },
    ];

    await db.insert(holdings).values(
      demoHoldings.map((h) => ({
        userId: user.id,
        symbol: h.symbol,
        amount: h.amount.toString(),
        avgPriceRub: h.avg.toFixed(2),
      }))
    );

    // Initial deposit ledger entry
    await db.insert(transactions).values({
      userId: user.id,
      type: "deposit",
      amountRub: "550000.00",
      note: "Первоначальное пополнение счёта",
    });

    // Demo buy orders + ledger entries
    const now = Date.now();
    const demoOrders = demoHoldings.map((h, i) => ({
      userId: user.id,
      symbol: h.symbol,
      side: "buy",
      type: "market",
      amount: h.amount.toString(),
      priceRub: h.avg.toFixed(2),
      totalRub: (h.amount * h.avg).toFixed(2),
      status: "filled",
      createdAt: new Date(now - (i + 1) * 3600_000 * 8),
    }));
    await db.insert(orders).values(demoOrders);

    await db.insert(transactions).values(
      demoHoldings.map((h, i) => ({
        userId: user.id,
        type: "buy",
        symbol: h.symbol,
        amountCoin: h.amount.toString(),
        amountRub: (h.amount * h.avg).toFixed(2),
        note: `Покупка ${h.symbol}`,
        createdAt: new Date(now - (i + 1) * 3600_000 * 8),
      }))
    );

    // An open limit order for flavor
    await db.insert(orders).values({
      userId: user.id,
      symbol: "BTC",
      side: "buy",
      type: "limit",
      amount: "0.01",
      priceRub: "8500000.00",
      totalRub: "85000.00",
      status: "open",
      createdAt: new Date(now - 3600_000 * 2),
    });

    await db.insert(watchlist).values(
      ["BTC", "ETH", "SOL", "DOGE"].map((symbol) => ({
        userId: user.id,
        symbol,
      }))
    );

    void price; // reserved for future use
  }

  seeded = true;
}
