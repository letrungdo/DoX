import type { Channel } from "./playlist.ts";

/**
 * Finding out whether a stream is actually playing.
 *
 * This is the part a phone cannot do. A playlist of this size always carries
 * dead links, and nothing in the file says which: the worst of them still
 * serve a perfectly good manifest pointing at segments that are gone, so the
 * picture stays black and nothing ever raises an error. The only way to know
 * is to fetch a segment and see whether video comes back.
 */

/** Some CDNs answer a bare client with a redirect to their homepage. */
export const BROWSER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36";

/** How long any single request to someone else's CDN gets. */
const REQUEST_TIMEOUT_MS = 8000;

/** How many streams are checked at once. */
const CONCURRENCY = 24;

export interface Verified {
  channel: Channel;
  /**
   * The streams the app should try, in order, or empty when the channel is
   * off the air.
   *
   * The first is the one seen playing here. The rest are the links the check
   * never got to — a stream that plays today can be gone tomorrow, and by
   * then the only thing worth having is another link to try.
   */
  urls: string[];
  checked: boolean;
}

/**
 * Finds a stream that plays for each channel, [CONCURRENCY] channels at a
 * time.
 *
 * A channel stops as soon as one of its links works, so the common case
 * costs a single check and the budget is spent on the channels that are in
 * trouble. What it stopped short of is kept: those links are unproven, not
 * dead, and two days from now the proven one may be the dead one.
 */
export async function check(
  channels: Channel[],
  deadline: number,
): Promise<Verified[]> {
  const results: Verified[] = new Array(channels.length);
  let next = 0;

  const worker = async () => {
    while (true) {
      const index = next++;
      if (index >= channels.length) return;
      const channel = channels[index];

      if (Date.now() > deadline) {
        // Out of time: the channel keeps its links in the order they were
        // ranked and goes out unverified rather than disappearing until the
        // next run.
        results[index] = { channel, urls: channel.sources, checked: false };
        continue;
      }

      // Only the links proved dead are dropped. A link the check stopped
      // before reaching stays on as a spare, behind the one that played.
      let playing = "";
      const untried: string[] = [];
      for (const [position, url] of channel.sources.entries()) {
        if (await isPlaying(url, channel.headers)) {
          playing = url;
          untried.push(...channel.sources.slice(position + 1));
          break;
        }
        if (Date.now() > deadline) {
          untried.push(...channel.sources.slice(position + 1));
          break;
        }
      }
      results[index] = {
        channel,
        urls: playing === "" ? untried : [playing, ...untried],
        checked: true,
      };
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, channels.length) }, worker),
  );
  return results;
}

/**
 * Whether [url] is a stream with video coming out of it right now.
 *
 * Three things have to hold, and only the last one is the interesting test: a
 * dead mirror passes the first two every time.
 */
async function isPlaying(
  url: string,
  headers: Record<string, string>,
): Promise<boolean> {
  try {
    const manifest = await get(url, headers);
    if (manifest === null || !manifest.body.startsWith("#EXTM3U")) return false;

    // A master playlist lists other playlists rather than segments; the
    // stream is one step further down.
    const media = manifest.body.includes("#EXT-X-STREAM-INF")
      ? await followVariant(manifest, headers)
      : manifest;
    if (media === null) return false;

    const segments = uris(media);
    if (segments.length === 0) return false;

    // The segment is the only thing that says the channel is on air. A
    // playlist someone committed to a repository a year ago still reads
    // perfectly; the video it points at is what has gone.
    //
    // The last segment first, because that is the live edge and the one a
    // player would open with. The first is the fallback: on a stream with a
    // short window the newest segment can still be being written, and on a
    // stale playlist neither is there, which is the answer either way.
    if (await hasBytes(segments[segments.length - 1], headers)) return true;
    return segments.length > 1 && await hasBytes(segments[0], headers);
  } catch {
    return false;
  }
}

interface Fetched {
  url: string;
  body: string;
}

async function get(
  url: string,
  headers: Record<string, string>,
): Promise<Fetched | null> {
  const response = await fetch(url, {
    headers: { "User-Agent": BROWSER_AGENT, ...headers },
    redirect: "follow",
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  return { url: response.url || url, body: await response.text() };
}

async function followVariant(
  master: Fetched,
  headers: Record<string, string>,
): Promise<Fetched | null> {
  const variants = uris(master);
  if (variants.length === 0) return null;
  const media = await get(variants[0], headers);
  if (media === null || !media.body.startsWith("#EXTM3U")) return null;
  return media;
}

/** The URIs a playlist points at, resolved against where it came from. */
function uris(playlist: Fetched): string[] {
  const found: string[] = [];
  for (const rawLine of playlist.body.split("\n")) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    try {
      found.push(new URL(line, playlist.url).toString());
    } catch {
      // A playlist that points at something that is not a URL points
      // nowhere; the entries around it may still be good.
    }
  }
  return found;
}

/**
 * Whether [url] actually serves data.
 *
 * Only the first kilobyte is asked for: this runs hundreds of times and the
 * question is whether anything comes back at all, not what it contains. A
 * server that ignores the range and sends the whole segment answers it just
 * as well, so the body is dropped as soon as the first chunk arrives.
 */
async function hasBytes(
  url: string,
  headers: Record<string, string>,
): Promise<boolean> {
  const response = await fetch(url, {
    headers: {
      "User-Agent": BROWSER_AGENT,
      ...headers,
      Range: "bytes=0-1023",
    },
    redirect: "follow",
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!response.ok || response.body === null) {
    await response.body?.cancel();
    return false;
  }

  const reader = response.body.getReader();
  try {
    const { value } = await reader.read();
    return (value?.length ?? 0) > 0;
  } finally {
    await reader.cancel();
  }
}
