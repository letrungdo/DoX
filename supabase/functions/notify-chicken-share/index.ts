// Sends a transactional email after chicken data has been shared.
//
// The caller must be signed in and must already have shared their data with
// the requested email. That second check prevents this endpoint from becoming
// a general-purpose email relay.
//
// Required secrets:
//   RESEND_API_KEY
//   RESEND_FROM_EMAIL (for example: "Do X <notifications@example.com>")

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RESEND_FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;",
  })[character]!);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ error: "Missing bearer token" }, 401);
  }

  let email: string;
  try {
    const body = await req.json();
    email = typeof body?.email === "string"
      ? body.email.trim().toLowerCase()
      : "";
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "Invalid email" }, 400);
  }

  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) {
    return json({ error: "Invalid session" }, 401);
  }

  // This RPC only returns viewers belonging to the signed-in owner. Matching
  // the recipient here proves that the share was created before we send.
  const { data: viewers, error: viewersError } = await caller.rpc(
    "get_chicken_share_viewers",
  );
  if (viewersError) {
    console.error("could not verify chicken share", viewersError.message);
    return json({ error: "Could not verify share" }, 500);
  }
  const recipient = (viewers ?? []).find((viewer) =>
    typeof viewer.viewer_email === "string" &&
    viewer.viewer_email.trim().toLowerCase() === email
  );
  if (!recipient) {
    return json({ error: "No matching chicken data share" }, 403);
  }

  if (!RESEND_API_KEY || !RESEND_FROM_EMAIL) {
    console.error("RESEND_API_KEY or RESEND_FROM_EMAIL is not configured");
    return json({ error: "Email service is not configured" }, 503);
  }

  const ownerEmail = user.email ?? "một người dùng Do X";
  const safeOwnerEmail = escapeHtml(ownerEmail);
  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to: [email],
      subject: "Bạn được chia sẻ dữ liệu gà trên Do X",
      text:
        `${ownerEmail} đã chia sẻ dữ liệu gà với bạn trên Do X. ` +
        "Bạn có quyền xem nhưng không thể thêm, sửa hoặc xóa dữ liệu. " +
        "Hãy mở ứng dụng Do X để xem dữ liệu được chia sẻ.",
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#202124">
          <h2 style="margin-bottom:12px">Bạn được chia sẻ dữ liệu gà</h2>
          <p><strong>${safeOwnerEmail}</strong> đã chia sẻ dữ liệu gà với bạn trên Do X.</p>
          <p>Bạn có quyền <strong>chỉ xem</strong>, không thể thêm, sửa hoặc xóa dữ liệu.</p>
          <p>Hãy mở ứng dụng Do X để xem dữ liệu được chia sẻ.</p>
        </div>
      `,
    }),
  });

  if (!resendResponse.ok) {
    const providerError = await resendResponse.text();
    console.error(
      `Resend rejected chicken share email: HTTP ${resendResponse.status}`,
      providerError,
    );
    return json({ error: "Email provider rejected the message" }, 502);
  }

  const result = await resendResponse.json();
  console.log("sent chicken share email", result.id);
  return json({ email_sent: true });
});
