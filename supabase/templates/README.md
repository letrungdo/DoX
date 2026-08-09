# Auth email templates

Supabase ships plain, unbranded emails ("Follow this link to confirm your
user"). These replace them with the Do X card: teal header, one button, the
raw link for clients that strip buttons, and the `{{ .Token }}` code for anyone
who would rather type it in.

> **Custom SMTP first.** A free-tier project on the built-in email provider
> cannot change a template at all — the API answers *"Email template
> modification is not available for free tier projects using the default email
> provider"*. Configure SMTP (below) before any of this takes.

| File | Supabase template |
| --- | --- |
| `confirm-signup.html` | Confirm signup |
| `recovery.html` | Reset password |
| `magic-link.html` | Magic link |
| `email-change.html` | Change email address |

## Installing them

Dashboard → **Authentication → Emails → Templates**: pick the template, paste
the file's contents, and set the subject line:

| Template | Subject |
| --- | --- |
| Confirm signup | `Kích hoạt tài khoản Do X của bạn` |
| Reset password | `Đặt lại mật khẩu Do X` |
| Magic link | `Liên kết đăng nhập Do X` |
| Change email address | `Xác nhận email mới cho Do X` |

Running the stack locally instead? Point `supabase/config.toml` at the files:

```toml
[auth.email.template.confirmation]
subject = "Kích hoạt tài khoản Do X của bạn"
content_path = "./supabase/templates/confirm-signup.html"

[auth.email.template.recovery]
subject = "Đặt lại mật khẩu Do X"
content_path = "./supabase/templates/recovery.html"

[auth.email.template.magic_link]
subject = "Liên kết đăng nhập Do X"
content_path = "./supabase/templates/magic-link.html"

[auth.email.template.email_change]
subject = "Xác nhận email mới cho Do X"
content_path = "./supabase/templates/email-change.html"
```

## Two settings the templates depend on

* **Authentication → URL Configuration → Redirect URLs** must allow
  `https://app.xn--t-lia.vn/auth/*`, or `{{ .ConfirmationURL }}` silently falls
  back to the site URL and the app never gets the session.
* **Authentication → SMTP Settings** — required, as above. The built-in sender
  is also capped at a couple of emails an hour and lands in spam, so it was
  never viable past testing anyway.
