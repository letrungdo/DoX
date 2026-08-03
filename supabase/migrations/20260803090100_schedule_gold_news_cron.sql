-- Rebuilds the gold-news digest three times a day, at 06:00 / 12:00 / 18:00
-- Vietnam time (23:00 the previous UTC day, then 05:00 and 11:00 UTC).
--
-- The call carries the publishable key, which is already shipped inside the
-- app — no project secret ends up in a migration. The function guards itself
-- against being triggered by anyone else: it only writes today or yesterday,
-- and returns the stored digest unchanged if it is less than 3 hours old.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'summarize-gold-news-daily',
  '0 23,5,11 * * *',
  $$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/summarize-gold-news',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
