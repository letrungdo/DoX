-- Add columns for price changes to the main gold_prices table.
alter table public.gold_prices
  add column bid_change numeric default 0,
  add column ask_change numeric default 0;

-- Table to store price history snapshots for calculating day-over-day changes.
create table public.gold_price_history (
  id bigint primary key generated always as identity,
  code text not null,
  bid numeric not null,
  ask numeric not null,
  created_at timestamptz not null default now()
);

-- Index to quickly find the last price for a given day.
create index idx_gold_price_history_code_created_at
  on public.gold_price_history(code, created_at desc);

alter table public.gold_price_history enable row level security;

-- Only service role (Edge Functions) can manage history, but anyone can read for analysis.
create policy "public read history" on public.gold_price_history
  for select to anon, authenticated using (true);
