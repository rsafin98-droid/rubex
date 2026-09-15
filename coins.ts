export type CoinSeed = {
  symbol: string;
  name: string;
  priceRub: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  color: string;
  rank: number;
};

// Approximate RUB prices for a lively demo market.
export const COIN_SEEDS: CoinSeed[] = [
  { symbol: "BTC", name: "Bitcoin", priceRub: 8950000, change24h: 2.34, volume24h: 2500000000000, marketCap: 176000000000000, color: "#F7931A", rank: 1 },
  { symbol: "ETH", name: "Ethereum", priceRub: 305000, change24h: 1.12, volume24h: 1200000000000, marketCap: 36700000000000, color: "#627EEA", rank: 2 },
  { symbol: "USDT", name: "Tether", priceRub: 91.5, change24h: 0.02, volume24h: 4500000000000, marketCap: 11200000000000, color: "#26A17B", rank: 3 },
  { symbol: "BNB", name: "BNB", priceRub: 56000, change24h: -0.87, volume24h: 180000000000, marketCap: 8100000000000, color: "#F0B90B", rank: 4 },
  { symbol: "SOL", name: "Solana", priceRub: 16800, change24h: 4.51, volume24h: 320000000000, marketCap: 7900000000000, color: "#14F195", rank: 5 },
  { symbol: "XRP", name: "XRP", priceRub: 54.2, change24h: 3.08, volume24h: 210000000000, marketCap: 3100000000000, color: "#23292F", rank: 6 },
  { symbol: "TON", name: "Toncoin", priceRub: 480, change24h: -1.44, volume24h: 45000000000, marketCap: 1200000000000, color: "#0098EA", rank: 7 },
  { symbol: "DOGE", name: "Dogecoin", priceRub: 12.8, change24h: 5.62, volume24h: 90000000000, marketCap: 1800000000000, color: "#C2A633", rank: 8 },
  { symbol: "ADA", name: "Cardano", priceRub: 38.9, change24h: -2.11, volume24h: 40000000000, marketCap: 1400000000000, color: "#0033AD", rank: 9 },
  { symbol: "TRX", name: "TRON", priceRub: 22.4, change24h: 0.94, volume24h: 30000000000, marketCap: 1900000000000, color: "#EB0029", rank: 10 },
  { symbol: "AVAX", name: "Avalanche", priceRub: 3150, change24h: 3.77, volume24h: 55000000000, marketCap: 1200000000000, color: "#E84142", rank: 11 },
  { symbol: "DOT", name: "Polkadot", priceRub: 640, change24h: -0.55, volume24h: 25000000000, marketCap: 900000000000, color: "#E6007A", rank: 12 },
  { symbol: "LINK", name: "Chainlink", priceRub: 1420, change24h: 2.19, volume24h: 38000000000, marketCap: 850000000000, color: "#2A5ADA", rank: 13 },
  { symbol: "MATIC", name: "Polygon", priceRub: 42.6, change24h: 1.85, volume24h: 22000000000, marketCap: 420000000000, color: "#8247E5", rank: 14 },
  { symbol: "LTC", name: "Litecoin", priceRub: 8900, change24h: -1.02, volume24h: 30000000000, marketCap: 670000000000, color: "#345D9D", rank: 15 },
];

export function formatRub(value: number, digits = 2): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
}
