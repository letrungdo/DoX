alter table public.cock_sales add column if not exists category text not null default 'fighting';
alter table public.expenses alter column batch_id drop not null;;
