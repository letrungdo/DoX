// Daily gold-price news digest.
//
// Pulls the last ~2 days of headlines from several RSS feeds (Vietnamese and
// international), asks Gemini to keep only what actually moves the gold price
// and summarise it in Vietnamese, then writes one `gold_news` row for today.
// A pg_cron job calls this once a day; the app only reads the table.
//
// The RSS reading, the Gemini call and the Google News link resolver live in
// `../_shared/news_feed.ts`, shared with `summarize-storm-news`.
//
// Secrets: GEMINI_API_KEY (required), GEMINI_MODEL (optional).

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  collectItems,
  Feed,
  generateJson,
  NewsItem,
  resolveArticleUrl,
  vnToday,
} from "../_shared/news_feed.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
const MAX_ITEMS = 45;
const LOOKBACK_HOURS = 48;

const FEEDS: Feed[] = [
  {
    url:
      "https://news.google.com/rss/search?q=gi%C3%A1+v%C3%A0ng+when:2d&hl=vi&gl=VN&ceid=VN:vi",
    source: "Google News (VN)",
    filter: false,
  },
  {
    url:
      "https://news.google.com/rss/search?q=gold+price+when:2d&hl=en-US&gl=US&ceid=US:en",
    source: "Google News (Gold)",
    filter: false,
  },
  {
    url:
      "https://news.google.com/rss/search?q=fed+interest+rate+inflation+dollar+index+when:2d&hl=en-US&gl=US&ceid=US:en",
    source: "Google News (Macro)",
    filter: false,
  },
  {
    url: "https://vnexpress.net/rss/kinh-doanh.rss",
    source: "VnExpress",
    filter: true,
  },
  {
    url: "https://cafef.vn/tai-chinh-quoc-te.rss",
    source: "CafeF",
    filter: true,
  },
  {
    url: "https://cafef.vn/vi-mo-dau-tu.rss",
    source: "CafeF",
    filter: true,
  },
];

/// Only used on the broad business feeds, to drop items that have nothing to
/// do with the gold price (property, stocks of a single company, ...).
const KEYWORDS = [
  "vàng",
  "sjc",
  "gold",
  "fed",
  "lãi suất",
  "interest rate",
  "lạm phát",
  "inflation",
  "usd",
  "tỷ giá",
  "dollar",
  "kim loại quý",
  "ngân hàng trung ương",
  "central bank",
];

const HIGHLIGHT_FIELDS = [
  "title_vi",
  "title_en",
  "detail_vi",
  "detail_en",
  "impact",
  "source_index",
];

const DIGEST_FIELDS = [
  "summary_vi",
  "summary_en",
  "sentiment",
  "sentiment_reason_vi",
  "sentiment_reason_en",
  "highlights",
];

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    summary_vi: { type: "STRING" },
    summary_en: { type: "STRING" },
    sentiment: { type: "STRING", enum: ["up", "down", "neutral"] },
    sentiment_reason_vi: { type: "STRING" },
    sentiment_reason_en: { type: "STRING" },
    highlights: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          title_vi: { type: "STRING" },
          title_en: { type: "STRING" },
          detail_vi: { type: "STRING" },
          detail_en: { type: "STRING" },
          impact: { type: "STRING", enum: ["up", "down", "neutral"] },
          source_index: { type: "INTEGER" },
        },
        required: HIGHLIGHT_FIELDS,
        propertyOrdering: HIGHLIGHT_FIELDS,
      },
    },
  },
  required: DIGEST_FIELDS,
  propertyOrdering: DIGEST_FIELDS,
};

interface Highlight {
  title_vi: string;
  title_en: string;
  detail_vi: string;
  detail_en: string;
  impact: string;
  source_index: number;
}

interface Digest {
  summary_vi: string;
  summary_en: string;
  sentiment: string;
  sentiment_reason_vi: string;
  sentiment_reason_en: string;
  highlights: Highlight[];
}

function buildPrompt(items: NewsItem[], date: string): string {
  const list = items
    .map((item, i) =>
      `[${i}] (${item.source}${item.publishedAt ? `, ${item.publishedAt}` : ""}) ${item.title}`
    )
    .join("\n");

  return `Bạn là chuyên gia phân tích thị trường vàng, viết bản tin cho người Việt Nam theo dõi giá vàng trong nước (SJC, nhẫn trơn) và giá vàng thế giới (XAU/USD).

Dưới đây là các tiêu đề tin tức thu thập trong 48 giờ qua từ nhiều nguồn, ngày ${date}:

${list}

Nhiệm vụ:
1. Bỏ qua mọi tin không liên quan tới giá vàng (bao gồm tin quảng cáo, tin doanh nghiệp đơn lẻ, tin trùng lặp).
2. Viết "summary_vi": 2-3 câu tiếng Việt tóm tắt bức tranh chung tác động tới giá vàng hôm nay.
3. Chọn 3-5 tin quan trọng nhất cho "highlights". Mỗi mục gồm:
   - "title_vi": tiêu đề ngắn gọn bằng tiếng Việt (tối đa 12 từ).
   - "detail_vi": 1-2 câu tiếng Việt giải thích tin đó ảnh hưởng thế nào tới giá vàng.
   - "impact": "up" nếu hỗ trợ giá vàng tăng, "down" nếu gây áp lực giảm, "neutral" nếu trung tính.
   - "source_index": số trong ngoặc vuông của tin gốc trong danh sách trên.
4. "sentiment": xu hướng tổng thể của giá vàng ngắn hạn ("up", "down" hoặc "neutral"), kèm "sentiment_reason_vi" là một câu tiếng Việt giải thích.
5. Ứng dụng có hai ngôn ngữ, nên mỗi đoạn văn bản cần một bản tiếng Anh tương ứng: "summary_en", "sentiment_reason_en", "title_en", "detail_en". Viết tiếng Anh tự nhiên như người bản xứ viết bản tin tài chính, cùng nội dung với bản tiếng Việt chứ không dịch máy từng chữ.

Chỉ dựa trên các tiêu đề được cung cấp, không bịa thêm số liệu. Trả về đúng JSON theo schema.`;
}

/// The cron only needs an anon-level key to call this, so the endpoint is in
/// practice public. A digest younger than this is returned as-is rather than
/// rebuilt, which keeps anyone else's calls from spending Gemini quota. Kept
/// under the 6h gap between scheduled runs so a late cron tick is never
/// mistaken for a duplicate.
const MIN_REBUILD_AGE_MS = 3 * 3600_000;

Deno.serve(async () => {
  try {
    const date = vnToday();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existing } = await supabase
      .from("gold_news")
      .select("updated_at")
      .eq("id", 1)
      .maybeSingle();
    if (
      existing &&
      Date.now() - Date.parse(existing.updated_at) < MIN_REBUILD_AGE_MS
    ) {
      return Response.json({ ok: true, date, skipped: "still fresh" });
    }

    const items = await collectItems({
      feeds: FEEDS,
      keywords: KEYWORDS,
      maxItems: MAX_ITEMS,
      lookbackHours: LOOKBACK_HOURS,
    });
    if (items.length === 0) {
      // Every feed was empty or refused us; surface it as an error so the run
      // is visible in the logs instead of quietly leaving yesterday's digest.
      console.error("no news collected from any feed");
      return Response.json({ error: "no news collected" }, { status: 502 });
    }

    const digest = await generateJson<Digest>(
      GEMINI_MODEL,
      buildPrompt(items, date),
      RESPONSE_SCHEMA,
    );

    // Only the articles the model actually cited are stored, in the order they
    // appear in the highlights, so the app can link each point to its source.
    const used: NewsItem[] = [];
    const highlights = digest.highlights.map((h) => {
      const item = items[h.source_index];
      let sourceIndex = -1;
      if (item) {
        sourceIndex = used.indexOf(item);
        if (sourceIndex < 0) sourceIndex = used.push(item) - 1;
      }
      return {
        title_vi: h.title_vi,
        title_en: h.title_en,
        detail_vi: h.detail_vi,
        detail_en: h.detail_en,
        impact: h.impact,
        source_index: sourceIndex,
      };
    });

    // Only the handful of cited links go through the resolver, so the extra
    // round trips stay cheap.
    const urls = await Promise.all(used.map((item) => resolveArticleUrl(item.url)));

    const row = {
      id: 1,
      date,
      summary_vi: digest.summary_vi,
      summary_en: digest.summary_en,
      sentiment: digest.sentiment,
      sentiment_reason_vi: digest.sentiment_reason_vi,
      sentiment_reason_en: digest.sentiment_reason_en,
      highlights,
      sources: used.map((item, i) => ({
        title: item.title,
        url: urls[i],
        source: item.source,
        published_at: item.publishedAt,
      })),
      model: GEMINI_MODEL,
      updated_at: new Date().toISOString(),
    };

    // Single-row table: the digest is always written over the previous one.
    const { error } = await supabase.from("gold_news").upsert(row, {
      onConflict: "id",
    });
    if (error) throw new Error(`upsert failed: ${error.message}`);

    return Response.json({ ok: true, collected: items.length, ...row });
  } catch (error) {
    console.error(error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
