// Gate for the functions that only pg_cron should run (`fetch-gold-price`,
// `summarize-gold-news`, `summarize-storm-news`, `refresh-tv-channels`).
//
// The publishable key ships inside the app, so it proves nothing about who is
// calling. The cron jobs instead read the `cron_secret` Vault value at run
// time and send it as `x-cron-secret`; the same value is set on the functions
// as `CRON_SECRET`. These functions are deployed with JWT verification off.

const CRON_SECRET = Deno.env.get("CRON_SECRET");

// Timing-safe so the secret cannot be recovered one byte at a time.
function secretMatches(candidate: string, expected: string): boolean {
  const a = new TextEncoder().encode(candidate);
  const b = new TextEncoder().encode(expected);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Returns the response to send back when [req] is not the cron job, or null
 * when the caller presented the right secret and the run may go ahead.
 */
export function rejectUnlessCron(req: Request): Response | null {
  if (!CRON_SECRET) {
    console.error("CRON_SECRET is not set");
    return json({ error: "Cron secret is not configured" }, 503);
  }
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (!secretMatches(presented, CRON_SECRET)) {
    return json({ error: "Forbidden" }, 403);
  }
  return null;
}
