-- Create asset_savings table
create table if not exists public.asset_savings (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
    bank_name text not null,
    amount double precision not null default 0,
    interest_rate double precision not null default 0,
    start_date date not null default current_date,
    term_months integer,
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Create asset_investments table
create table if not exists public.asset_investments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
    symbol text not null,
    type text not null check (type in ('stock', 'crypto')),
    quantity double precision not null default 0,
    buy_price double precision not null default 0,
    buy_date date not null default current_date,
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Create asset_gold table
create table if not exists public.asset_gold (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
    gold_type text not null,
    quantity double precision not null default 0,
    buy_price double precision not null default 0,
    buy_date date not null default current_date,
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.asset_savings enable row level security;
alter table public.asset_investments enable row level security;
alter table public.asset_gold enable row level security;

-- Create RLS policies
create policy "Users can manage their own savings" on public.asset_savings
    for all using (auth.uid() = user_id);

create policy "Users can manage their own investments" on public.asset_investments
    for all using (auth.uid() = user_id);

create policy "Users can manage their own gold" on public.asset_gold
    for all using (auth.uid() = user_id);

-- Create updated_at trigger function if it doesn't exist
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- Apply triggers
create trigger handle_asset_savings_updated_at
    before update on public.asset_savings
    for each row execute procedure public.handle_updated_at();

create trigger handle_asset_investments_updated_at
    before update on public.asset_investments
    for each row execute procedure public.handle_updated_at();

create trigger handle_asset_gold_updated_at
    before update on public.asset_gold
    for each row execute procedure public.handle_updated_at();
