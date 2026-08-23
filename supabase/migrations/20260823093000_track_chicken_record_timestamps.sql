-- Server-side create/update stamps for the "new"/"edited" badges.
--
-- The badges used to be a local log on one device, so nobody else could see
-- them — least of all a viewer of shared data. Reading them off the rows makes
-- them the same for everyone.
--
-- Backfilled from what is already known (a batch's created_at for its child
-- rows) rather than from now(), so turning this on does not badge the whole
-- history as brand new.

alter table public.batch_sales
  add column if not exists created_at timestamptz;

update public.batch_sales s
   set created_at = b.created_at
  from public.chicken_batches b
 where b.id = s.batch_id and s.created_at is null;

alter table public.batch_sales
  alter column created_at set default now(),
  alter column created_at set not null;

alter table public.chicken_batches
  add column if not exists updated_at timestamptz;
alter table public.expenses
  add column if not exists updated_at timestamptz;
alter table public.cock_sales
  add column if not exists updated_at timestamptz;
alter table public.batch_sales
  add column if not exists updated_at timestamptz;

update public.chicken_batches set updated_at = created_at where updated_at is null;
update public.expenses set updated_at = created_at where updated_at is null;
update public.cock_sales set updated_at = created_at where updated_at is null;
update public.batch_sales set updated_at = created_at where updated_at is null;

alter table public.chicken_batches
  alter column updated_at set default now(),
  alter column updated_at set not null;
alter table public.expenses
  alter column updated_at set default now(),
  alter column updated_at set not null;
alter table public.cock_sales
  alter column updated_at set default now(),
  alter column updated_at set not null;
alter table public.batch_sales
  alter column updated_at set default now(),
  alter column updated_at set not null;

create schema if not exists private;

-- The client never sends these columns; the row itself keeps them honest, so a
-- stale or wrong device clock cannot backdate an edit.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  new.created_at = old.created_at;
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.chicken_batches;
create trigger set_updated_at before update on public.chicken_batches
  for each row execute function private.set_updated_at();

drop trigger if exists set_updated_at on public.expenses;
create trigger set_updated_at before update on public.expenses
  for each row execute function private.set_updated_at();

drop trigger if exists set_updated_at on public.cock_sales;
create trigger set_updated_at before update on public.cock_sales
  for each row execute function private.set_updated_at();

drop trigger if exists set_updated_at on public.batch_sales;
create trigger set_updated_at before update on public.batch_sales
  for each row execute function private.set_updated_at();

-- The read endpoints now hand the stamps to the client. Only the shared
-- variants are listed: the owner-only ones delegate to these.
create or replace function public.get_shared_chicken_batches(
  p_owner_id uuid,
  p_year int default null
)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'name', b.name,
        'incubation_date', b.incubation_date,
        'quantity', b.quantity,
        'actual_hatch_date', b.actual_hatch_date,
        'created_at', b.created_at,
        'updated_at', b.updated_at,
        'vaccinations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', v.id,
            'title', v.title,
            'scheduled_date', v.scheduled_date,
            'is_completed', v.is_completed
          ) order by v.scheduled_date)
          from public.vaccinations v
          where v.batch_id = b.id and v.user_id = p_owner_id
        ), '[]'::jsonb),
        'expenses', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', e.id,
            'type', e.type,
            'amount', e.amount,
            'date', e.date,
            'note', e.note,
            'created_at', e.created_at,
            'updated_at', e.updated_at
          ) order by e.date, e.created_at)
          from public.expenses e
          where e.batch_id = b.id and e.user_id = p_owner_id
        ), '[]'::jsonb),
        'cock_sales', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', s.id,
            'note', s.note,
            'amount', s.amount,
            'date', s.date,
            'category', s.category,
            'created_at', s.created_at,
            'updated_at', s.updated_at
          ) order by s.date, s.created_at)
          from public.cock_sales s
          where s.batch_id = b.id and s.user_id = p_owner_id
        ), '[]'::jsonb),
        'batch_sales', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', s.id,
            'date', s.date,
            'quantity', s.quantity,
            'amount', s.amount,
            'note', s.note,
            'created_at', s.created_at,
            'updated_at', s.updated_at
          ) order by s.date)
          from public.batch_sales s
          where s.batch_id = b.id and s.user_id = p_owner_id
        ), '[]'::jsonb)
      ) order by b.incubation_date desc, b.created_at desc
    )
    from public.chicken_batches b
    where b.user_id = p_owner_id
      and (p_year is null
        or extract(year from b.incubation_date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;

create or replace function public.get_shared_global_cock_sales(
  p_owner_id uuid,
  p_year int default null
)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'note', s.note,
      'amount', s.amount,
      'date', s.date,
      'category', s.category,
      'created_at', s.created_at,
      'updated_at', s.updated_at
    ) order by s.date desc, s.created_at desc)
    from public.cock_sales s
    where s.user_id = p_owner_id and s.batch_id is null
      and (p_year is null or extract(year from s.date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;

create or replace function public.get_shared_global_expenses(
  p_owner_id uuid,
  p_year int default null
)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', e.id,
      'type', e.type,
      'amount', e.amount,
      'date', e.date,
      'note', e.note,
      'created_at', e.created_at,
      'updated_at', e.updated_at
    ) order by e.date desc, e.created_at desc)
    from public.expenses e
    where e.user_id = p_owner_id and e.batch_id is null
      and (p_year is null or extract(year from e.date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;
