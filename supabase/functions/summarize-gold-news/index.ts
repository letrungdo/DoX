// Daily gold-price news digest.
//
// Pulls the last ~2 days of headlines from several RSS feeds (Vietnamese and
// international), asks Gemini to keep only what actually moves the gold price
// and summarise it in Vietnamese, then writes one `gold_news` row for today.
// A pg_cron job calls this once a day; the app only reads the table.
//
// Secrets: GEMINI_API_KEY (required), GEMINI_MODEL (optional).

import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
const MAX_ITEMS = 45;
const LOOKBACK_HOURS = 48;
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

interface Feed {
  url: string;
  source: string;
  /** Broad feeds need keyword filtering; targeted searches do not. */
  filter: boolean;
}

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

interface NewsItem {
  title: string;
  url: string;
  source: string;
  publishedAt: string | null;
}

function decodeEntities(input: string): string {
  return input
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function tag(xml: string, name: string): string | null {
  const match = xml.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`, "i"));
  return match ? decodeEntities(match[1]) : null;
}

/// Minimal RSS 2.0 reader. A real XML parser would be overkill here: every
/// feed we use is flat `<item>` markup and we only need four fields.
function parseRss(xml: string, feed: Feed): NewsItem[] {
  const items: NewsItem[] = [];
  for (const block of xml.match(/<item[\s\S]*?<\/item>/gi) ?? []) {
    const rawTitle = tag(block, "title");
    const link = tag(block, "link");
    if (!rawTitle || !link) continue;

    // Google News appends " - Publisher" to every headline and also exposes
    // the publisher in a <source> tag; prefer the tag and strip the suffix.
    const publisher = tag(block, "source");
    let title = rawTitle;
    if (publisher && title.endsWith(` - ${publisher}`)) {
      title = title.slice(0, -(publisher.length + 3)).trim();
    }

    items.push({
      title,
      url: link,
      source: publisher ?? feed.source,
      publishedAt: tag(block, "pubDate"),
    });
  }
  return items;
}

async function fetchFeed(feed: Feed): Promise<NewsItem[]> {
  try {
    const res = await fetch(feed.url, {
      headers: { "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(15_000),
    });
    if (!res.ok) {
      console.warn(`feed ${feed.url} -> HTTP ${res.status}`);
      return [];
    }
    const items = parseRss(await res.text(), feed);
    if (!feed.filter) return items;
    return items.filter((item) => {
      const haystack = item.title.toLowerCase();
      return KEYWORDS.some((k) => haystack.includes(k));
    });
  } catch (error) {
    console.warn(`feed ${feed.url} failed:`, error);
    return [];
  }
}

/// A Google News RSS link points at a `news.google.com/rss/articles/...`
/// wrapper that only resolves through JavaScript — tapping it in the app lands
/// on a blank page. The wrapper page carries the three values Google's own
/// front-end posts back to get the real address, so we do the same round trip
/// here and store the publisher's URL instead. Falls back to the wrapper if
/// anything about that handshake changes.
async function resolveArticleUrl(url: string): Promise<string> {
  if (!url.includes("news.google.com")) return url;
  try {
    const page = await fetch(url, {
      headers: { "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(20_000),
    });
    const html = await page.text();
    const attr = (name: string) =>
      html.match(new RegExp(`${name}="([^"]+)"`))?.[1];
    const id = attr("data-n-a-id");
    const ts = attr("data-n-a-ts");
    const signature = attr("data-n-a-sg");
    if (!id || !ts || !signature) return url;

    const request = JSON.stringify([
      "garturlreq",
      [
        ["X", "X", ["X", "X"], null, null, 1, 1, "US:en", null, 1, null, null,
          null, null, null, 0, 1],
        "X",
        "X",
        1,
        [1, 1, 1],
        1,
        1,
        null,
        0,
        0,
        null,
        0,
      ],
      id,
      Number(ts),
      signature,
    ]);
    const res = await fetch(
      "https://news.google.com/_/DotsSplashUi/data/batchexecute",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "User-Agent": USER_AGENT,
        },
        body: new URLSearchParams({
          "f.req": JSON.stringify([[["Fbv4je", request, null, "generic"]]]),
        }),
        signal: AbortSignal.timeout(20_000),
      },
    );
    for (const line of (await res.text()).split("\n")) {
      if (!line.includes("garturlres")) continue;
      const resolved = JSON.parse(JSON.parse(line)[0][2])[1];
      if (typeof resolved === "string" && resolved.startsWith("http")) {
        return resolved;
      }
    }
  } catch (error) {
    console.warn(`could not resolve ${url}:`, error);
  }
  return url;
}

function withinLookback(item: NewsItem, now: number): boolean {
  if (!item.publishedAt) return true; // Undated items are kept; Gemini can judge.
  const at = Date.parse(item.publishedAt);
  if (Number.isNaN(at)) return true;
  return now - at <= LOOKBACK_HOURS * 3600_000;
}

function normalizeTitle(title: string): string {
  return title.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

async function collectItems(): Promise<NewsItem[]> {
  const now = Date.now();
  const perFeed = await Promise.all(FEEDS.map(fetchFeed));
  const seen = new Set<string>();
  const items: NewsItem[] = [];
  // Round-robin across feeds so one prolific source cannot fill the cap.
  for (let i = 0; items.length < MAX_ITEMS; i++) {
    let advanced = false;
    for (const feedItems of perFeed) {
      if (i >= feedItems.length) continue;
      advanced = true;
      const item = feedItems[i];
      if (!withinLookback(item, now)) continue;
      const key = normalizeTitle(item.title);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      items.push(item);
      if (items.length >= MAX_ITEMS) break;
    }
    if (!advanced) break;
  }
  return items;
}

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

async function summarize(items: NewsItem[], date: string): Promise<Digest> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: buildPrompt(items, date) }] }],
        generationConfig: {
          temperature: 0.3,
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
        },
      }),
      signal: AbortSignal.timeout(90_000),
    },
  );

  if (!res.ok) {
    throw new Error(`Gemini HTTP ${res.status}: ${await res.text()}`);
  }
  const payload = await res.json();
  const text = payload?.candidates?.[0]?.content?.parts
    ?.map((p: { text?: string }) => p.text ?? "")
    .join("") ?? "";
  if (!text.trim()) throw new Error("Gemini returned an empty response");

  return JSON.parse(text) as Digest;
}

/// Today in Vietnam (UTC+7) as `YYYY-MM-DD` — the digest is stamped with the
/// day its readers see, not the UTC day the cron happens to fire on.
function vnToday(): string {
  return new Date(Date.now() + 7 * 3600_000).toISOString().slice(0, 10);
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

    const items = await collectItems();
    if (items.length === 0) {
      return Response.json({ error: "no news collected" }, { status: 502 });
    }

    const digest = await summarize(items, date);

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
