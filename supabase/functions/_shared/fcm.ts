// Firebase Cloud Messaging plumbing shared by the functions that push:
// `notify-chicken-activity` (one account's shared data changed) and
// `summarize-storm-news` (a storm is coming, tell every device).
//
// Requires the FCM_SERVICE_ACCOUNT secret: the Firebase service account JSON,
// verbatim.

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/// A registration token plus the language its owner reads, straight out of
/// `device_tokens`.
export interface PushDevice {
  token: string;
  locale: string;
}

export interface PushContent {
  title: string;
  body: string;
  data: Record<string, string>;
  /// Android channel the system should file this under while the app is not
  /// running. It has to be one the app creates at startup, otherwise Android
  /// falls back to its own channel and the importance we picked is lost.
  androidChannelId: string;
}

export interface PushResult {
  sent: number;
  /** Tokens FCM refused for good; the caller deletes them. */
  stale: string[];
}

// FCM's HTTP v1 API only takes an OAuth token, which means signing a JWT with
// the service account key here — there is no Google SDK in this runtime.
export async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const base64url = (input: string) =>
    btoa(input).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${base64url(JSON.stringify(header))}.${
    base64url(JSON.stringify(claim))
  }`;

  const pem = account.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (character) => character.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const signed = `${unsigned}.${
    base64url(String.fromCharCode(...new Uint8Array(signature)))
  }`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signed,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google rejected the assertion: ${await response.text()}`);
  }
  return (await response.json()).access_token as string;
}

/// Sends one notification per device, worded by [content] for that device's
/// language. Throws only when no token could be minted at all — a device FCM
/// refuses is reported through [PushResult.stale] instead, so one dead install
/// cannot stop the rest of the batch.
export async function sendPush(
  devices: PushDevice[],
  content: (locale: string) => PushContent,
): Promise<PushResult> {
  if (devices.length === 0) return { sent: 0, stale: [] };

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT is not set");
  const account = JSON.parse(raw) as ServiceAccount;
  const bearer = await accessToken(account);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  const stale: string[] = [];
  await Promise.all(devices.map(async (device) => {
    const { title, body, data, androidChannelId } = content(device.locale);
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: { channel_id: androidChannelId },
          },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (response.ok) {
      sent++;
      return;
    }
    // A token dies when the app is uninstalled or reinstalled. Google keeps
    // answering 404/400 for it forever, so drop it rather than retry it daily.
    const failure = await response.text();
    if (response.status === 404 || response.status === 400) {
      stale.push(device.token);
    }
    console.error(`FCM rejected a token: HTTP ${response.status}`, failure);
  }));

  return { sent, stale };
}
