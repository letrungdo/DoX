import { createClient } from "jsr:@supabase/supabase-js@2";
import { curate, parsePlaylist } from "./playlist.ts";
import { BROWSER_AGENT, check } from "./check.ts";

/**
 * Rebuilds the Vietnamese channel list, weekly.
 *
 * Two playlists go in — the curated `iptv-org` file and a community
 * collection that has everything it misses — and one list comes out, with
 * every channel on it verified to be playing right now.
 *
 * Verified is the whole point. A playlist of this size always carries dead
 * links, and nothing in the file says which: the worst of them still serve a
 * perfectly good manifest pointing at segments that are gone, so the picture
 * stays black and nothing ever raises an error. The only way to know is to
 * fetch a segment and see whether video comes back, which is what happens
 * here so that no phone ever has to.
 */

const PRIMARY_PLAYLIST = "https://iptv-org.github.io/iptv/countries/vn.m3u";

/**
 * The community collection, rebuilt daily from a few thousand public
 * sources. Almost all of what it adds is provincial stations, which the
 * curated catalogue barely covers.
 */
const EXTRA_PLAYLIST =
  "https://raw.githubusercontent.com/hnduy910/IPTVHND-Collector/main/iptvhnd-vietnam-live.m3u";

const COUNTRY = "VN";

/**
 * When the checking stops, whatever is left unchecked.
 *
 * The function has a wall clock to stay inside, and a run that is cut off
 * mid-way has to still produce a list — a week with no channels at all would
 * be far worse than a week with a few dead ones. Whatever has not been
 * reached by then keeps its best link and goes out unverified.
 */
const CHECK_BUDGET_MS = 110_000;

Deno.serve(async () => {
  const startedAt = Date.now();
  try {
    const [primary, extra] = await Promise.all([
      fetchPlaylist(PRIMARY_PLAYLIST),
      // The second list is a bonus, not a dependency: without it the run
      // still produces the catalogue's channels, which is what the page
      // showed before there was a second source at all.
      fetchPlaylist(EXTRA_PLAYLIST).catch(() => ""),
    ]);

    const channels = curate(parsePlaylist(primary), parsePlaylist(extra));
    if (channels.length === 0) throw new Error("No channels parsed");

    const deadline = startedAt + CHECK_BUDGET_MS;
    const verified = await check(channels, deadline);

    const playing = verified.filter((entry) => entry.urls.length > 0);
    if (playing.length === 0) throw new Error("No channel is playing");

    const rows = playing.map((entry, index) => ({
      slug: entry.channel.slug,
      name: entry.channel.name,
      url: entry.urls[0],
      // The spares, behind the link that played, for the app to fall back on
      // when this one has died before the next weekly run.
      urls: entry.urls,
      logo: entry.channel.logo,
      categories: entry.channel.categories,
      quality: entry.channel.quality,
      is_geo_blocked: entry.channel.isGeoBlocked,
      is_intermittent: entry.channel.isIntermittent,
      headers: entry.channel.headers,
      sort_order: index,
    }));

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { error } = await supabase.rpc("replace_tv_channels", {
      p_country: COUNTRY,
      p_rows: rows,
    });
    if (error) throw error;

    return Response.json({
      success: true,
      found: channels.length,
      playing: playing.length,
      unchecked: playing.filter((entry) => !entry.checked).length,
      seconds: Math.round((Date.now() - startedAt) / 1000),
    });
  } catch (error) {
    return Response.json({ error: String(error) }, { status: 500 });
  }
});

async function fetchPlaylist(url: string): Promise<string> {
  const response = await fetch(url, {
    headers: { "User-Agent": BROWSER_AGENT },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return await response.text();
}
