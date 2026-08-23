// RSS + Gemini plumbing shared by the news digests (`summarize-gold-news`,
// `summarize-storm-news`). Both do the same three things — read a handful of
// RSS feeds, hand the headlines to Gemini under a JSON schema, resolve the
// Google News wrapper links of the articles it cited — so that part lives here
// and each function only carries its own feeds, prompt and schema.

export const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

export interface Feed {
  url: string;
  source: string;
  /** Broad feeds need keyword filtering; targeted searches do not. */
  filter: boolean;
}

export interface NewsItem {
  title: string;
  url: string;
  source: string;
  publishedAt: string | null;
}

export interface RetryOptions {
  /** Total number of attempts, including the first one. */
  attempts: number;
  /** Delay before the second attempt; doubled for each one after that. */
  backoffMs: number;
  timeoutMs: number;
  label: string;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/// Both upstreams we depend on hand out 503s under load — Google News when it
/// throttles the runtime's IP, Gemini when the model is busy. Neither is a real
/// failure, so retry a few times with a growing delay before giving up.
export async function fetchWithRetry(
  url: string,
  init: RequestInit,
  options: RetryOptions,
): Promise<Response> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= options.attempts; attempt++) {
    if (attempt > 1) {
      await sleep(options.backoffMs * 2 ** (attempt - 2));
    }
    try {
      const res = await fetch(url, {
        ...init,
        signal: AbortSignal.timeout(options.timeoutMs),
      });
      // 4xx other than 429 will not change on a retry.
      if (res.ok || (res.status < 500 && res.status !== 429)) return res;
      lastError = new Error(`HTTP ${res.status}`);
      if (attempt === options.attempts) return res;
      console.warn(
        `${options.label} -> HTTP ${res.status}, retrying (${attempt}/${options.attempts})`,
      );
    } catch (error) {
      lastError = error;
      if (attempt === options.attempts) break;
      console.warn(
        `${options.label} failed, retrying (${attempt}/${options.attempts}):`,
        error,
      );
    }
  }
  throw lastError;
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
  const match = xml.match(
    new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`, "i"),
  );
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

async function fetchFeed(feed: Feed, keywords: string[]): Promise<NewsItem[]> {
  try {
    const res = await fetchWithRetry(
      feed.url,
      { headers: { "User-Agent": USER_AGENT } },
      {
        attempts: 3,
        backoffMs: 1_000,
        timeoutMs: 15_000,
        label: `feed ${feed.url}`,
      },
    );
    if (!res.ok) {
      console.warn(`feed ${feed.url} -> HTTP ${res.status}`);
      return [];
    }
    const items = parseRss(await res.text(), feed);
    if (!feed.filter) return items;
    return items.filter((item) => {
      const haystack = item.title.toLowerCase();
      return keywords.some((k) => haystack.includes(k));
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
export async function resolveArticleUrl(url: string): Promise<string> {
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

function withinLookback(
  item: NewsItem,
  now: number,
  lookbackHours: number,
): boolean {
  if (!item.publishedAt) return true; // Undated items are kept; Gemini can judge.
  const at = Date.parse(item.publishedAt);
  if (Number.isNaN(at)) return true;
  return now - at <= lookbackHours * 3600_000;
}

function normalizeTitle(title: string): string {
  return title.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

export interface CollectOptions {
  feeds: Feed[];
  /** Applied to the feeds marked `filter: true`. Lower-case. */
  keywords: string[];
  maxItems: number;
  lookbackHours: number;
}

export async function collectItems(
  options: CollectOptions,
): Promise<NewsItem[]> {
  const now = Date.now();
  const perFeed = await Promise.all(
    options.feeds.map((feed) => fetchFeed(feed, options.keywords)),
  );
  const seen = new Set<string>();
  const items: NewsItem[] = [];
  // Round-robin across feeds so one prolific source cannot fill the cap.
  for (let i = 0; items.length < options.maxItems; i++) {
    let advanced = false;
    for (const feedItems of perFeed) {
      if (i >= feedItems.length) continue;
      advanced = true;
      const item = feedItems[i];
      if (!withinLookback(item, now, options.lookbackHours)) continue;
      const key = normalizeTitle(item.title);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      items.push(item);
      if (items.length >= options.maxItems) break;
    }
    if (!advanced) break;
  }
  return items;
}

/// One Gemini call with a JSON schema, parsed into `T`. Every digest wants the
/// same settings: low temperature, JSON only, three long attempts.
export async function generateJson<T>(
  model: string,
  prompt: string,
  responseSchema: unknown,
): Promise<T> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  const res = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          responseMimeType: "application/json",
          responseSchema,
        },
      }),
    },
    // Three 90s attempts plus the waits stay inside the function's wall clock.
    { attempts: 3, backoffMs: 5_000, timeoutMs: 90_000, label: "gemini" },
  );

  if (!res.ok) {
    throw new Error(`Gemini HTTP ${res.status}: ${await res.text()}`);
  }
  const payload = await res.json();
  const text = payload?.candidates?.[0]?.content?.parts
    ?.map((p: { text?: string }) => p.text ?? "")
    .join("") ?? "";
  if (!text.trim()) throw new Error("Gemini returned an empty response");

  return JSON.parse(text) as T;
}

/// Today in Vietnam (UTC+7) as `YYYY-MM-DD` — a digest is stamped with the day
/// its readers see, not the UTC day the cron happens to fire on.
export function vnToday(): string {
  return new Date(Date.now() + 7 * 3600_000).toISOString().slice(0, 10);
}
