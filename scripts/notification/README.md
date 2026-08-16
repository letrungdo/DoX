# Testing a notification tap by hand

Two payloads for the iOS simulator, one per notification that navigates
somewhere. Drag the file onto the simulator window, or:

```bash
xcrun simctl push booted vn.dox.app scripts/notification/<file>.apns
```

Worth doing each one three times: with the app open (the banner is shown over
it), with the app in the background (⌘⇧H), and with the app killed — those are
three different code paths. Test with the page in the bottom bar and again with
it moved to the menu in Settings, since the two are navigated to differently.

## chicken_activity.apns — a share owner recorded a sale

The payload the `notify-chicken-activity` function sends. Tapping it should
land on the chicken page showing the data of the account in `owner_id`.

Put a real owner id in `owner_id` first — the `ownerId` of a source the
signed-in account can read:

```sql
select owner_id, viewer_id from chicken_data_shares;
```

`REPLACE_WITH_OWNER_UUID` on its own only proves the navigation: the page opens
but the data source stays where it was, because the id matches nothing this
account is allowed to read.

`gcm.message_id` is what makes firebase_messaging treat the payload as one of
its own; without it the tap never reaches `onMessageOpenedApp`.

## electric_reminder.apns — the monthly electricity bill reminder

This one is normally a *local* notification, scheduled for the 1st of the
month, so there is no server to ask for a copy. The payload imitates one
instead: `NotificationId`, `presentAlert`, `presentSound`, `presentBadge` and
`payload` together are what flutter_local_notifications recognises as its own
notification, and `payload` is the value the app switches on. Tapping it should
open the electricity page on last month.

Waiting for the real thing instead: turn the reminder on in the electricity
settings and move the device clock to the last minute of a month.

Both halves of this depend on `AppDelegate`: it claims
`UNUserNotificationCenter.delegate` before the plugins register, so a local
notification tap reaches flutter_local_notifications at all, and it answers the
"show this while the app is open?" question itself rather than leaving it to
whichever plugin replies first. See the comments there.

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
