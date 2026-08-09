create table public.gold_news (
  date date primary key,
  summary text not null,
  sentiment text not null check (sentiment in ('up', 'down', 'neutral')),
  sentiment_reason text,
  highlights jsonb not null default '[]'::jsonb,
  sources jsonb not null default '[]'::jsonb,
  model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gold_news enable row level security;

create policy "public read" on public.gold_news for select to anon, authenticated using (true);;
