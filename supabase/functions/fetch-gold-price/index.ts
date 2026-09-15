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

    // Filter for PNJ and SJC gold types only
    const wanted = ["PNJ", "SJC"];
    const now = new Date().toISOString();

    const rows = hcm.gold_type
      .filter((t) => wanted.includes(t.name))
      .map((t) => ({
        code: `${t.name}_HCM`.toUpperCase(),
        name: t.name,
        desc: "TP. Hồ Chí Minh",
        bid: parsePrice(t.gia_mua),
        ask: parsePrice(t.gia_ban),
        updated_at: now,
      }));

    if (rows.length === 0) {
      return new Response("No target gold types found", { status: 404 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Persist filtered prices to database
    const { error } = await supabase.from("gold_prices").upsert(rows);

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({ success: true, updated: rows }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
