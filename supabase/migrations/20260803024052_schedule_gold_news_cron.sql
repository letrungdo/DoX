create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'summarize-gold-news-daily',
  '20 0 * * *',
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
);;
