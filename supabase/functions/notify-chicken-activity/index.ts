// Pushes a notification to everyone a chicken dataset is shared with, after
// the owner records a sale or an expense.
//
// Called by the `notify_chicken_activity` database triggers, never by the app:
// there is no user session behind an INSERT that arrives through the offline
// sync queue, and the recipients' device tokens belong to other accounts. The
// caller proves itself with the shared secret the migration put in Vault, so
// this function runs with JWT verification off.
//
// The FCM plumbing lives in `../_shared/fcm.ts`, shared with
// `summarize-storm-news`.
//
// Required secrets:
//   CHICKEN_NOTIFY_SECRET  — the `chicken_notify_secret` Vault value
//   FCM_SERVICE_ACCOUNT    — the Firebase service account JSON, verbatim

import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NOTIFY_SECRET = Deno.env.get("CHICKEN_NOTIFY_SECRET");
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT");

type Kind = "cock_sale" | "batch_sale" | "expense";

interface DeviceToken {
  token: string;
  user_id: string;
  locale: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Timing-safe so the secret cannot be recovered one byte at a time.
function secretMatches(candidate: string, expected: string): boolean {
  const a = new TextEncoder().encode(candidate);
  const b = new TextEncoder().encode(expected);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function formatAmount(total: number, locale: string): string {
  return new Intl.NumberFormat(locale === "en" ? "en-US" : "vi-VN", {
    maximumFractionDigits: 0,
  }).format(total);
}

function messageFor(
  kind: Kind,
  count: number,
  total: number,
  ownerEmail: string,
  locale: string,
): { title: string; body: string } {
  const amount = formatAmount(total, locale);
  if (locale === "en") {
    const title = kind === "expense" ? "New expense" : "Chickens sold";
    const what = kind === "cock_sale"
      ? `sold ${count} cock${count > 1 ? "s" : ""}`
      : kind === "batch_sale"
      ? `sold a batch (${count} record${count > 1 ? "s" : ""})`
      : `added ${count} expense${count > 1 ? "s" : ""}`;
    return { title, body: `${ownerEmail} ${what} — ${amount} đ` };
  }
  const title = kind === "expense" ? "Chi phí mới" : "Có gà vừa bán";
  const what = kind === "cock_sale"
    ? `vừa bán ${count} con gà`
    : kind === "batch_sale"
    ? `vừa bán gà theo lứa (${count} lần)`
    : `vừa thêm ${count} khoản chi`;
  return { title, body: `${ownerEmail} ${what} — ${amount} đ` };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!NOTIFY_SECRET || !FCM_SERVICE_ACCOUNT) {
    console.error("CHICKEN_NOTIFY_SECRET or FCM_SERVICE_ACCOUNT is not set");
    return json({ error: "Push is not configured" }, 503);
  }
  const presented = req.headers.get("x-notify-secret") ?? "";
  if (!secretMatches(presented, NOTIFY_SECRET)) {
    return json({ error: "Forbidden" }, 403);
  }

  let ownerId: string;
  let kind: Kind;
  let count: number;
  let total: number;
  try {
    const body = await req.json();
    ownerId = String(body.owner_id ?? "");
    kind = body.kind;
    count = Number(body.count ?? 0);
    total = Number(body.total ?? 0);
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!ownerId || !["cock_sale", "batch_sale", "expense"].includes(kind)) {
    return json({ error: "Invalid payload" }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const { data: shares, error: sharesError } = await admin
    .from("chicken_data_shares")
    .select("viewer_id")
    .eq("owner_id", ownerId);
  if (sharesError) {
    console.error("could not read chicken shares", sharesError.message);
    return json({ error: "Could not read shares" }, 500);
  }
  const viewerIds = (shares ?? []).map((share) => share.viewer_id);
  if (viewerIds.length === 0) return json({ sent: 0 });

  const { data: devices, error: devicesError } = await admin
    .from("device_tokens")
    .select("token, user_id, locale")
    .in("user_id", viewerIds);
  if (devicesError) {
    console.error("could not read device tokens", devicesError.message);
    return json({ error: "Could not read device tokens" }, 500);
  }
  const tokens = (devices ?? []) as DeviceToken[];
  if (tokens.length === 0) return json({ sent: 0 });

  const { data: owner } = await admin.auth.admin.getUserById(ownerId);
  const ownerEmail = owner?.user?.email ?? "Một người dùng Do X";

  let result;
  try {
    result = await sendPush(tokens, (locale) => {
      const { title, body } = messageFor(kind, count, total, ownerEmail, locale);
      return {
        title,
        body,
        data: { type: "chicken_activity", kind, owner_id: ownerId },
        androidChannelId: "shared_chicken_activity",
      };
    });
  } catch (error) {
    console.error("could not send the chicken push", error);
    return json({ error: "Push provider is unavailable" }, 502);
  }

  if (result.stale.length > 0) {
    await admin.from("device_tokens").delete().in("token", result.stale);
  }

  return json({ sent: result.sent, dropped: result.stale.length });
});
