export type User = {
  id: number;
  username: string;
  displayName: string;
  cashBalance: number;
};

export type Coin = {
  symbol: string;
  name: string;
  priceRub: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  color: string;
  rank: number;
};

export type Position = {
  symbol: string;
  name: string;
  color: string;
  amount: number;
  avgPriceRub: number;
  priceRub: number;
  change24h: number;
  value: number;
  cost: number;
  pnl: number;
  pnlPct: number;
};

export type Portfolio = {
  cashBalance: number;
  holdingsValue: number;
  totalValue: number;
  totalPnl: number;
  positions: Position[];
};

export type Order = {
  id: number;
  symbol: string;
  side: "buy" | "sell";
  type: "market" | "limit";
  amount: number;
  priceRub: number;
  totalRub: number;
  status: "filled" | "open" | "canceled";
  createdAt: string;
};

export type Transaction = {
  id: number;
  type: "deposit" | "withdraw" | "buy" | "sell";
  symbol: string | null;
  amountCoin: number | null;
  amountRub: number;
  note: string | null;
  createdAt: string;
};
