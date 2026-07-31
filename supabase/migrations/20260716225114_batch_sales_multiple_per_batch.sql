create table public.batch_sales (
  id uuid primary key,
  batch_id uuid not null references public.chicken_batches(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id),
  date date not null,
  quantity integer not null default 0,
  amount double precision not null,
  note text
);

alter table public.batch_sales enable row level security;

create policy "owner select" on public.batch_sales for select using ((select auth.uid()) = user_id);
create policy "owner insert" on public.batch_sales for insert with check ((select auth.uid()) = user_id);
create policy "owner update" on public.batch_sales for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner delete" on public.batch_sales for delete using ((select auth.uid()) = user_id);

alter table public.chicken_batches drop column if exists sale_date;
alter table public.chicken_batches drop column if exists total_sale_amount;
alter table public.chicken_batches drop column if exists sale_quantity;;
