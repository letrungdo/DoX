# Chicken share email notification

This authenticated Edge Function sends a read-only chicken-data sharing notice
through Resend. It only accepts an email that already appears in the caller's
own `get_chicken_share_viewers` result.

Configure these project secrets before using it in production:

```sh
supabase secrets set \
  RESEND_API_KEY=your_resend_api_key \
  'RESEND_FROM_EMAIL=Do X <notifications@xn--t-lia.vn>' \
  --project-ref fyyrgwohjgvsmwqgxiga
```

The sender domain must be verified in Resend. Secrets are intentionally not
stored in this repository and become available without redeploying the
function.
