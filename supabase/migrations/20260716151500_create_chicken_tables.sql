create table public.chicken_batches (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  incubation_date date not null,
  quantity int not null,
  actual_hatch_date date,
  sale_date date,
  total_sale_amount double precision,
  sale_quantity int,
  created_at timestamptz not null default now()
);

create table public.vaccinations (
  id uuid primary key,
  batch_id uuid not null references public.chicken_batches(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  scheduled_date date not null,
  is_completed boolean not null default false
);

create table public.expenses (
  id uuid primary key,
  batch_id uuid not null references public.chicken_batches(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null,
  amount double precision not null,
  date date not null,
  note text
);

create table public.cock_sales (
  id uuid primary key,
  batch_id uuid references public.chicken_batches(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  note text not null default '',
  amount double precision not null,
  date date not null
);

create index chicken_batches_user_id_idx on public.chicken_batches(user_id);
create index vaccinations_batch_id_idx on public.vaccinations(batch_id);
create index vaccinations_user_id_idx on public.vaccinations(user_id);
create index expenses_batch_id_idx on public.expenses(batch_id);
create index expenses_user_id_idx on public.expenses(user_id);
create index cock_sales_batch_id_idx on public.cock_sales(batch_id);
create index cock_sales_user_id_idx on public.cock_sales(user_id);

alter table public.chicken_batches enable row level security;
alter table public.vaccinations enable row level security;
alter table public.expenses enable row level security;
alter table public.cock_sales enable row level security;

create policy "owner select" on public.chicken_batches for select to authenticated using ((select auth.uid()) = user_id);
create policy "owner insert" on public.chicken_batches for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "owner update" on public.chicken_batches for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner delete" on public.chicken_batches for delete to authenticated using ((select auth.uid()) = user_id);

create policy "owner select" on public.vaccinations for select to authenticated using ((select auth.uid()) = user_id);
create policy "owner insert" on public.vaccinations for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "owner update" on public.vaccinations for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner delete" on public.vaccinations for delete to authenticated using ((select auth.uid()) = user_id);

create policy "owner select" on public.expenses for select to authenticated using ((select auth.uid()) = user_id);
create policy "owner insert" on public.expenses for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "owner update" on public.expenses for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner delete" on public.expenses for delete to authenticated using ((select auth.uid()) = user_id);

create policy "owner select" on public.cock_sales for select to authenticated using ((select auth.uid()) = user_id);
create policy "owner insert" on public.cock_sales for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "owner update" on public.cock_sales for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner delete" on public.cock_sales for delete to authenticated using ((select auth.uid()) = user_id);;
