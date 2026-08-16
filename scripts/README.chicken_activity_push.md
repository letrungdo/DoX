# Testing the shared-activity push by hand

`chicken_activity.apns` is the payload the `notify-chicken-activity` function
sends, in the shape the iOS simulator accepts. Tapping it should land on the
chicken page showing the data of the account in `owner_id`.

1. Put a real owner id in `owner_id` — the `ownerId` of a source the signed-in
   account can read. The quickest way to read one:

   ```sql
   select owner_id, viewer_id from chicken_data_shares;
   ```

   `REPLACE_WITH_OWNER_UUID` on its own only proves the navigation: the page
   opens on the chicken tab but the data source stays where it was, because the
   id matches nothing this account is allowed to read.

2. Run the app on a simulator, then either drag `chicken_activity.apns` onto
   the simulator window, or:

   ```bash
   xcrun simctl push booted vn.dox.app scripts/chicken_activity.apns
   ```

   Background the app first (⌘⇧H) — a push that arrives in the foreground is
   drawn by the app itself, which is the other path worth testing.

`gcm.message_id` is what makes firebase_messaging treat the payload as one of
its own; without it the tap never reaches `onMessageOpenedApp`.

## Android

A simulator payload has no Android equivalent, so send a real message to the
device token instead — `device_tokens` holds it, and the function itself is the
easiest sender:

```bash
curl -X POST "$SUPABASE_URL/functions/v1/notify-chicken-activity" \
  -H "x-notify-secret: $CHICKEN_NOTIFY_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"owner_id":"<owner uuid>","kind":"cock_sale","count":5,"total":1250000}'
```

It pushes every device the owner's data is shared with, which is what the
database trigger does after a real sale.
