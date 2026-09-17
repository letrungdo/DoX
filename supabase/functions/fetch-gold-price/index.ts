import { createClient } from "jsr:@supabase/supabase-js@2";

const PNJ_API_URL = "https://edge-cf-api.pnj.io/ecom-frontend/v3/get-gold-price";

interface GoldType {
  name: string;
  gia_ban: string;
  gia_mua: string;
  updated_at: string;
}

interface Location {
  name: string;
  gold_type: GoldType[];
}

interface PnjResponse {
  locations: Location[];
}

/**
 * Parses a price string from the PNJ API into VND per tael.
 * PNJ quotes thousands of VND with Vietnamese grouping, so "146.500" means
 * 146,500 thousand VND -> 146,500,000 VND.
 */
const parsePrice = (s: string): number => {
  const normalized = s.replace(/\./g, "").replace(",", ".");

  return parseFloat(normalized) * 1000;
};

/**
 * A gold price is never below this, so a reference snapshot under it was
 * written in a different unit and must not be subtracted from today's price.
 */
const MIN_PLAUSIBLE_PRICE = 1000000;

/**
 * The rows the app shows. PNJ quotes the plain ring under the nationwide
 * "Giá vàng nữ trang" section rather than under a city, so each target names
 * the location it lives in.
 */
const TARGETS = [
  {
    location: "Giá vàng nữ trang",
    goldType: "Nhẫn Trơn PNJ 999.9",
    code: "PNJ_RING_9999",
    name: "Vàng nhẫn 9999",
    desc: "PNJ Hồ Chí Minh",
  },
  {
    location: "TPHCM",
    goldType: "SJC",
    code: "SJC_HCM",
    name: "Vàng miếng SJC",
    desc: "SJC Hồ Chí Minh",
  },
];

Deno.serve(async () => {
  try {
    const response = await fetch(PNJ_API_URL, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36",
        "Referer": "https://giavang.pnj.com.vn/",
      },
    });

    if (!response.ok) {
      throw new Error(`PNJ API error: ${response.statusText}`);
    }

    const data: PnjResponse = await response.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const now = new Date();
    const nowIso = now.toISOString();

    // Calculate start of today in ICT (UTC+7) to find yesterday's last price
    // If it's 9 AM ICT, start of today is 2 AM UTC.
    const ictOffset = 7 * 60 * 60 * 1000;
    const todayIct = new Date(now.getTime() + ictOffset);
    todayIct.setUTCHours(0, 0, 0, 0);
    const startOfTodayUtc = new Date(todayIct.getTime() - ictOffset).toISOString();

    const results = [];
    const historyRows = [];

    for (const target of TARGETS) {
      const location = data.locations.find((l) => l.name === target.location);
      const t = location?.gold_type.find((g) => g.name === target.goldType);

      if (!t) {
        throw new Error(
          `${target.goldType} not found in PNJ location ${target.location}`,
        );
      }

      const code = target.code;
      const currentBid = parsePrice(t.gia_mua);
      const currentAsk = parsePrice(t.gia_ban);

      // Fetch the last price from a previous day to calculate "Day Change"
      const { data: refData } = await supabase
        .from("gold_price_history")
        .select("bid, ask")
        .eq("code", code)
        .lt("created_at", startOfTodayUtc)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const refBid = Number(refData?.bid);
      const refAsk = Number(refData?.ask);
      const bidChange = refBid >= MIN_PLAUSIBLE_PRICE ? currentBid - refBid : 0;
      const askChange = refAsk >= MIN_PLAUSIBLE_PRICE ? currentAsk - refAsk : 0;

      results.push({
        code,
        name: target.name,
        desc: target.desc,
        bid: currentBid,
        ask: currentAsk,
        bid_change: bidChange,
        ask_change: askChange,
        updated_at: nowIso,
      });

      historyRows.push({
        code,
        bid: currentBid,
        ask: currentAsk,
        created_at: nowIso,
      });
    }

    // Update main prices table with calculated changes
    const { error: upsertError } = await supabase.from("gold_prices").upsert(results);
    if (upsertError) throw upsertError;

    // Record current snapshot in history
    const { error: historyError } = await supabase.from("gold_price_history").insert(historyRows);
    if (historyError) throw historyError;

    return new Response(JSON.stringify({ success: true, updated: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
