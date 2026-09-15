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
 * Parses a price string from PNJ API into a numeric value.
 * Example: "145.300" -> 145.3
 */
const parsePrice = (s: string): number => {
  return parseFloat(s.replace(",", "."));
};

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

    // Filter for TPHCM location
    const hcm = data.locations.find((l) => l.name === "TPHCM");

    if (!hcm) {
      throw new Error("HCM location not found in PNJ response");
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Filter for PNJ and SJC gold types only
    const wanted = ["PNJ", "SJC"];
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

    for (const t of hcm.gold_type) {
      if (!wanted.includes(t.name)) continue;

      const code = `${t.name}_HCM`.toUpperCase();
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

      const bidChange = refData ? currentBid - (refData.bid as number) : 0;
      const askChange = refData ? currentAsk - (refData.ask as number) : 0;

      results.push({
        code,
        name: t.name,
        desc: "TP. Hồ Chí Minh",
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

    if (results.length === 0) {
      return new Response("No target gold types found", { status: 404 });
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
