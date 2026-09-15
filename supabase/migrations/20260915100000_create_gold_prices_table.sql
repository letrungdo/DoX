-- Table to store gold prices for PNJ and SJC HCM, populated by an Edge Function.
-- Data is updated periodically via a cron job.
create table public.gold_prices (
  code text primary key,
  name text not null,
  "desc" text,
  bid numeric,
  ask numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gold_prices enable row level security;

create policy "public read" on public.gold_prices
  for select to anon, authenticated using (true);

-- Update gold prices every 30 minutes during business hours.
-- Schedule: Monday to Saturday, 08:00 to 20:30 ICT (01:00 to 13:30 UTC).
-- PNJ usually updates prices in the morning and fluctuates throughout the day.
select cron.schedule(
  'fetch-gold-price-periodic',
  '*/30 1-13 * * 1-6',
  $$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/fetch-gold-price',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
