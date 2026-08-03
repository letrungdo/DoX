-- Digest of the news that moves the gold price: several RSS sources are
-- collected and summarised by Gemini in the `summarize-gold-news` edge
-- function. The app only ever shows the newest digest, so the table holds a
-- single row that every run overwrites — `date` says which day it describes.
create table public.gold_news (
  id smallint primary key default 1 check (id = 1),
  date date not null,
  -- Written in both of the app's languages by the same Gemini call; the
  -- language-neutral parts (sentiment, impact, sources) are stored once.
  summary_vi text not null,
  summary_en text not null,
  sentiment text not null check (sentiment in ('up', 'down', 'neutral')),
  sentiment_reason_vi text,
  sentiment_reason_en text,
  highlights jsonb not null default '[]'::jsonb,
  sources jsonb not null default '[]'::jsonb,
  model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gold_news enable row level security;

-- Public data, so anonymous reads are allowed. Writes never go through RLS:
-- the edge function uses the service role key.
create policy "public read" on public.gold_news for select to anon, authenticated using (true);
