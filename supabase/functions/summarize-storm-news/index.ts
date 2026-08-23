// Storm alert digest.
//
// Reads the last ~30 hours of Vietnamese storm headlines, asks Gemini whether a
// storm or tropical depression is actually affecting Vietnam right now (or is
// forecast to within about three days), and writes one `storm_news` row. When
// there is nothing to warn about the row is stored with `active: false` and the
// app shows no card at all.
//
// A live storm is also pushed to every registered device — see `shouldNotify`
// for the rule that keeps a multi-day storm from notifying every three hours.
//
// Secrets: GEMINI_API_KEY (required), GEMINI_MODEL (optional),
// FCM_SERVICE_ACCOUNT (required for the push).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { PushDevice, sendPush } from "../_shared/fcm.ts";
import {
  collectItems,
  Feed,
  generateJson,
  NewsItem,
  resolveArticleUrl,
  vnToday,
} from "../_shared/news_feed.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
const MAX_ITEMS = 40;
// Shorter than the gold digest's 48h: a storm bulletin from two days ago says
// nothing about where the storm is now.
const LOOKBACK_HOURS = 30;

const FEEDS: Feed[] = [
  {
    url:
      "https://news.google.com/rss/search?q=b%C3%A3o+OR+%22%C3%A1p+th%E1%BA%A5p+nhi%E1%BB%87t+%C4%91%E1%BB%9Bi%22+when:2d&hl=vi&gl=VN&ceid=VN:vi",
    source: "Google News (VN)",
    filter: false,
  },
  {
    url:
      "https://news.google.com/rss/search?q=%22tin+b%C3%A3o%22+OR+%22b%C3%A3o+s%E1%BB%91%22+OR+%22si%C3%AAu+b%C3%A3o%22+when:2d&hl=vi&gl=VN&ceid=VN:vi",
    source: "Google News (Bão)",
    filter: false,
  },
  {
    url:
      "https://news.google.com/rss/search?q=typhoon+Vietnam+when:2d&hl=en-US&gl=US&ceid=US:en",
    source: "Google News (Typhoon)",
    filter: false,
  },
  {
    url: "https://vnexpress.net/rss/thoi-su.rss",
    source: "VnExpress",
    filter: true,
  },
  {
    url: "https://tuoitre.vn/rss/thoi-su.rss",
    source: "Tuổi Trẻ",
    filter: true,
  },
  {
    url: "https://vnexpress.net/rss/khoa-hoc.rss",
    source: "VnExpress",
    filter: true,
  },
];

/// Only used on the broad news feeds, to drop items that have nothing to do
/// with a storm.
const KEYWORDS = [
  "bão",
  "áp thấp nhiệt đới",
  "typhoon",
  "storm",
  "gió giật",
  "mưa lớn",
  "mưa to",
  "lũ",
  "ngập",
  "sạt lở",
  "sơ tán",
  "cảnh báo thiên tai",
];

const HIGHLIGHT_FIELDS = [
  "title_vi",
  "title_en",
  "detail_vi",
  "detail_en",
  "source_index",
];

const DIGEST_FIELDS = [
  "active",
  "name_vi",
  "name_en",
  "severity",
  "headline_vi",
  "headline_en",
  "summary_vi",
  "summary_en",
  "advice_vi",
  "advice_en",
  "highlights",
];

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    active: { type: "BOOLEAN" },
    name_vi: { type: "STRING" },
    name_en: { type: "STRING" },
    severity: { type: "STRING", enum: ["watch", "warning", "emergency"] },
    headline_vi: { type: "STRING" },
    headline_en: { type: "STRING" },
    summary_vi: { type: "STRING" },
    summary_en: { type: "STRING" },
    advice_vi: { type: "STRING" },
    advice_en: { type: "STRING" },
    highlights: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          title_vi: { type: "STRING" },
          title_en: { type: "STRING" },
          detail_vi: { type: "STRING" },
          detail_en: { type: "STRING" },
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
  source_index: number;
}

interface Digest {
  active: boolean;
  name_vi: string;
  name_en: string;
  severity: string;
  headline_vi: string;
  headline_en: string;
  summary_vi: string;
  summary_en: string;
  advice_vi: string;
  advice_en: string;
  highlights: Highlight[];
}

function buildPrompt(items: NewsItem[], date: string): string {
  const list = items
    .map((item, i) =>
      `[${i}] (${item.source}${
        item.publishedAt ? `, ${item.publishedAt}` : ""
      }) ${item.title}`
    )
    .join("\n");

  return `Bạn là chuyên gia phòng chống thiên tai, viết cảnh báo bão cho người Việt Nam đang theo dõi tình hình quê nhà.

Dưới đây là các tiêu đề tin tức thu thập trong 30 giờ qua từ nhiều nguồn, hôm nay là ngày ${date}:

${list}

Nhiệm vụ:
1. Xác định xem HIỆN TẠI có bão hoặc áp thấp nhiệt đới đang ảnh hưởng Việt Nam, hoặc được dự báo ảnh hưởng trong khoảng 3 ngày tới, hay không.
   - "active": true nếu có, false nếu không.
   - Chỉ đặt true khi các tiêu đề nói về một cơn bão/áp thấp đang hoạt động hoặc sắp vào. Tin tổng kết thiệt hại của cơn bão đã tan, tin hồi tưởng, tin về bão ở vùng khác không liên quan Việt Nam thì "active" = false.
2. Nếu "active" = false: đặt tất cả các trường văn bản còn lại là chuỗi rỗng "", "severity" = "watch", "highlights" = [].
3. Nếu "active" = true:
   - "name_vi": tên cơn bão như báo Việt Nam gọi, ví dụ "Bão số 5 (Kajiki)" hoặc "Áp thấp nhiệt đới trên Biển Đông".
   - "name_en": tên tương ứng bằng tiếng Anh, ví dụ "Typhoon Kajiki (storm No. 5)".
   - "severity": "watch" nếu còn xa hoặc mới hình thành, "warning" nếu sắp đổ bộ hoặc đang gây mưa gió mạnh, "emergency" nếu là bão rất mạnh/siêu bão đang đổ bộ hoặc đã có thiệt hại nghiêm trọng.
   - "headline_vi": một câu ngắn (tối đa 15 từ) nói vị trí/diễn biến mới nhất, ví dụ "Bão số 5 mạnh cấp 12 đang tiến vào vịnh Bắc Bộ".
   - "summary_vi": 2-3 câu tóm tắt diễn biến, vùng ảnh hưởng và thời điểm dự kiến.
   - "advice_vi": 1-2 câu khuyến nghị cho người dân vùng ảnh hưởng.
   - "highlights": 2-5 mục quan trọng nhất, mỗi mục gồm "title_vi" (tối đa 12 từ), "detail_vi" (1-2 câu) và "source_index" là số trong ngoặc vuông của tin gốc trong danh sách trên.
4. Ứng dụng có hai ngôn ngữ, nên mỗi đoạn văn bản cần một bản tiếng Anh tương ứng: "headline_en", "summary_en", "advice_en", "title_en", "detail_en". Viết tiếng Anh tự nhiên như bản tin thời tiết của người bản xứ, cùng nội dung với bản tiếng Việt chứ không dịch máy từng chữ.

Chỉ dựa trên các tiêu đề được cung cấp, không bịa thêm số liệu về cấp gió, toạ độ hay thời điểm đổ bộ. Trả về đúng JSON theo schema.`;
}

const SEVERITY_RANK: Record<string, number> = {
  watch: 0,
  warning: 1,
  emergency: 2,
};

/// A storm hangs around for days while the cron runs every three hours, so most
/// runs must stay silent. A push goes out when the reader has something new to
/// learn: a different storm than the one they were told about, a storm that has
/// got worse, or the same storm a whole day later.
const RENOTIFY_AFTER_MS = 24 * 3600_000;

interface NotifyState {
  notified_at: string | null;
  notified_name: string | null;
  notified_severity: string | null;
}

function shouldNotify(previous: NotifyState | null, digest: Digest): boolean {
  if (!digest.active) return false;
  if (!previous?.notified_at || !previous.notified_name) return true;
  if (previous.notified_name !== digest.name_vi) return true;
  const before = SEVERITY_RANK[previous.notified_severity ?? "watch"] ?? 0;
  const now = SEVERITY_RANK[digest.severity] ?? 0;
  if (now > before) return true;
  return Date.now() - Date.parse(previous.notified_at) >= RENOTIFY_AFTER_MS;
}

const SEVERITY_PREFIX: Record<string, { vi: string; en: string }> = {
  watch: { vi: "Theo dõi", en: "Watch" },
  warning: { vi: "Cảnh báo", en: "Warning" },
  emergency: { vi: "Khẩn cấp", en: "Emergency" },
};

/// Everyone with a registered device hears about a storm, whatever else they
/// use the app for — so this reads the whole table rather than one account's
/// rows. `locale` decides which half of the bilingual bulletin they get.
async function notifyEveryDevice(
  // deno-lint-ignore no-explicit-any
  admin: any,
  digest: Digest,
): Promise<{ sent: number; dropped: number }> {
  const { data, error } = await admin
    .from("device_tokens")
    .select("token, locale");
  if (error) {
    console.error("could not read device tokens", error.message);
    return { sent: 0, dropped: 0 };
  }
  const devices = (data ?? []) as PushDevice[];
  if (devices.length === 0) return { sent: 0, dropped: 0 };

  const result = await sendPush(devices, (locale) => {
    const english = locale === "en";
    const prefix = SEVERITY_PREFIX[digest.severity] ?? SEVERITY_PREFIX.watch;
    const name = english ? digest.name_en : digest.name_vi;
    const headline = english ? digest.headline_en : digest.headline_vi;
    const summary = english ? digest.summary_en : digest.summary_vi;
    return {
      title: `${english ? prefix.en : prefix.vi}: ${name}`,
      body: headline || summary,
      data: { type: "storm_news", severity: digest.severity },
      androidChannelId: "storm_alert",
    };
  });

  if (result.stale.length > 0) {
    await admin.from("device_tokens").delete().in("token", result.stale);
  }
  return { sent: result.sent, dropped: result.stale.length };
}

/// The cron only needs an anon-level key to call this, so the endpoint is in
/// practice public. A digest younger than this is returned as-is rather than
/// rebuilt, which keeps anyone else's calls from spending Gemini quota. Kept
/// under the 3h gap between scheduled runs so a late cron tick is never
/// mistaken for a duplicate.
const MIN_REBUILD_AGE_MS = 2 * 3600_000;

Deno.serve(async () => {
  try {
    const date = vnToday();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existing } = await supabase
      .from("storm_news")
      .select("updated_at, notified_at, notified_name, notified_severity")
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
      // Every feed was empty or refused us. Bail out rather than write
      // `active: false`: "we could not read the news" is not "no storm".
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
    const highlights = digest.active
      ? digest.highlights.map((h) => {
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
          source_index: sourceIndex,
        };
      })
      : [];

    // Only the handful of cited links go through the resolver, so the extra
    // round trips stay cheap.
    const urls = await Promise.all(
      used.map((item) => resolveArticleUrl(item.url)),
    );

    // With no storm, only the flag and the timestamp matter: the text columns
    // are cleared so a stale bulletin can never resurface.
    const row = {
      id: 1,
      date,
      active: digest.active,
      name_vi: digest.active ? digest.name_vi : null,
      name_en: digest.active ? digest.name_en : null,
      severity: digest.active ? digest.severity : "watch",
      headline_vi: digest.active ? digest.headline_vi : null,
      headline_en: digest.active ? digest.headline_en : null,
      summary_vi: digest.active ? digest.summary_vi : null,
      summary_en: digest.active ? digest.summary_en : null,
      advice_vi: digest.active ? digest.advice_vi : null,
      advice_en: digest.active ? digest.advice_en : null,
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

    const notify = shouldNotify(existing ?? null, digest);
    // Single-row table: the bulletin is always written over the previous one.
    // The `notified_*` columns are only touched when we are about to push, so a
    // silent run cannot reset the anti-spam clock.
    const { error } = await supabase.from("storm_news").upsert(
      notify
        ? {
          ...row,
          notified_at: new Date().toISOString(),
          notified_name: digest.name_vi,
          notified_severity: digest.severity,
        }
        : row,
      { onConflict: "id" },
    );
    if (error) throw new Error(`upsert failed: ${error.message}`);

    // After the upsert: a push nobody can act on is worse than a late one, so
    // the bulletin the notification points at is on the table first. A failure
    // here is logged and the run still counts as a success.
    let push = { sent: 0, dropped: 0 };
    if (notify) {
      try {
        push = await notifyEveryDevice(supabase, digest);
      } catch (error) {
        console.error("could not push the storm alert", error);
      }
    }

    return Response.json({
      ok: true,
      collected: items.length,
      notified: notify,
      ...push,
      ...row,
    });
  } catch (error) {
    console.error(error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
