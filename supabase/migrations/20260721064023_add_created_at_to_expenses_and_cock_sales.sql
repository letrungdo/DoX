alter table public.expenses
  add column if not exists created_at timestamptz not null default now();

alter table public.cock_sales
  add column if not exists created_at timestamptz not null default now();;
