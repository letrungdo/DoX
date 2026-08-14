import { createClient } from "jsr:@supabase/supabase-js@2";
import { DOMParser } from "jsr:@b-fuze/deno-dom";

// Only the Apps Script deployment key is kept as a secret; the URL is built
// from it here. The other endpoints are public, so they are hardcoded.
const APPS_SCRIPT_URL =
  `https://script.google.com/macros/s/${Deno.env.get("GOOGLE_SHEET_KEY")}/exec`;
const MONEYGRAM_URL =
  "https://ewm.digitalwalletcorp.com/EWA/DP/Tenant/1/Calculation?TenantID=1&DPType=15&ToCountry=VNM&RemitAmount=1000&BeneficiaryCurrency=VND&PointForFee=0&sendAmount=1000&sendCurrency=JPY&deliveryOption=BANK_DEPOSIT&RemittenceMethod=1&BankCode=970436&BankName=VIETCOMBANK%20-%20JOINT%20STOCK%20COMMERCIAL%20BANK%20FOR%20FOREIGN%20TRADE%20OF%20VIETNAM&ReceiveAgentID=73247188&RegionCode=JP&FromCurrency=JPY";
const SMILE_URL =
  "https://ewm.digitalwalletcorp.com/EWA/WalletEx/ExchangeRate?TenantID=1&RegionCode=JP&CurrencyCode=JPY";
const DCOM_URL = "https://sendmoney.co.jp/en/fx-rate";

const num = (v: unknown): number | null => {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

// Google — Apps Script returns ready-made JSON (no HTML parsing / fallback).
async function fetchGoogle(): Promise<number | null> {
  const d = await fetch(APPS_SCRIPT_URL, { redirect: "follow" }).then((r) => r.json());
  return num(d?.google_jpy_vnd);
}

// MoneyGram.
async function fetchMoneyGram(): Promise<number | null> {
  const d = await fetch(MONEYGRAM_URL).then((r) => r.json());
  return num(d?.Rate);
}

// Smile — the "Rates" field is a JSON string nested inside the response.
async function fetchSmile(): Promise<number | null> {
  const d = await fetch(SMILE_URL).then((r) => r.json());
  const rates = JSON.parse(d?.Rates);
  return num(rates?.ALL_ALL_ALL?.Currency?.Currency_JPY_VND?.SellingRate);
}

// Dcom — scrape the public fx-rate page. The VND row holds a nested table
// whose cells look like "VND 161.0000"; take the largest value found.
async function fetchDcom(): Promise<number | null> {
  const html = await fetch(DCOM_URL, {
    headers: { "User-Agent": "Mozilla/5.0" },
  }).then((r) => r.text());

  const doc = new DOMParser().parseFromString(html, "text/html");
  const tbody = doc?.querySelector("table.country-table tbody");
  if (!tbody) return null;

  // Direct-child <tr> only, to skip the rows of the nested table.
  const rows = [...tbody.children].filter((e) => e.tagName === "TR");
  for (const row of rows) {
    const cols = [...row.children].filter((e) => e.tagName === "TD");
    if (cols.length < 3) continue;

    const code = cols[0].textContent.match(/\(([^)]+)\)/)?.[1];
    if (code !== "VND") continue;

    const nested = cols[1].querySelector("table");
    if (!nested) return null;

    let max: number | null = null;
    for (const cell of nested.querySelectorAll("td")) {
      const parts = cell.textContent.trim().split(/\s+/);
      if (parts.length < 2) continue;
      // Drop any "(T+1)" suffix, then parse the number.
      const v = num(parts[1].replace(/\(.*\)/, ""));
      if (v != null && (max == null || v > max)) max = v;
    }
    return max;
  }
  return null;
}

const SOURCES: { code: string; fetch: () => Promise<number | null> }[] = [
  { code: "google_jpy_vnd", fetch: fetchGoogle },
  { code: "moneygram_jpy_vnd", fetch: fetchMoneyGram },
  { code: "smile_jpy_vnd", fetch: fetchSmile },
  { code: "dcom_jpy_vnd", fetch: fetchDcom },
];

Deno.serve(async () => {
  const now = new Date().toISOString();

  // Fetch every source in parallel; a failing source is skipped, not fatal.
  const results = await Promise.all(
    SOURCES.map((s) => s.fetch().then((rate) => ({ code: s.code, rate })).catch(() => ({ code: s.code, rate: null }))),
  );

  const rows = results
    .filter((r) => r.rate != null)
    .map((r) => ({ code: r.code, rate: r.rate as number, updated_at: now }));

  if (rows.length === 0) {
    return new Response("no rate fetched", { status: 502 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // service role: write bypasses RLS
  );
  const { error } = await supabase.from("fx_rates").upsert(rows);
  if (error) return new Response(error.message, { status: 500 });

  const failed = results.filter((r) => r.rate == null).map((r) => r.code);
  return new Response(JSON.stringify({ updated: rows, failed }), {
    headers: { "Content-Type": "application/json" },
  });
});
