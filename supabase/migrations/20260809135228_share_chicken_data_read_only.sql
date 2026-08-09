-- Owners can share their complete chicken dataset with another registered
-- account. Shared users only receive SELECT policies; every existing write
-- policy remains owner-only.
create table public.chicken_data_shares (
  owner_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, viewer_id),
  constraint chicken_data_shares_not_self check (owner_id <> viewer_id)
);

create index chicken_data_shares_viewer_id_idx
  on public.chicken_data_shares(viewer_id);

alter table public.chicken_data_shares enable row level security;

create policy "share participants select"
on public.chicken_data_shares for select to authenticated
using ((select auth.uid()) in (owner_id, viewer_id));

create policy "owner delete share"
on public.chicken_data_shares for delete to authenticated
using ((select auth.uid()) = owner_id);

grant select, delete on public.chicken_data_shares to authenticated;

-- Each child table carries the same owner id as its batch. A separate
-- permissive SELECT policy composes with the existing owner policy, while all
-- INSERT/UPDATE/DELETE policies remain unchanged.
create policy "shared viewer select" on public.chicken_batches
for select to authenticated using (exists (
  select 1 from public.chicken_data_shares share
  where share.owner_id = chicken_batches.user_id
    and share.viewer_id = (select auth.uid())
));

create policy "shared viewer select" on public.vaccinations
for select to authenticated using (exists (
  select 1 from public.chicken_data_shares share
  where share.owner_id = vaccinations.user_id
    and share.viewer_id = (select auth.uid())
));

create policy "shared viewer select" on public.expenses
for select to authenticated using (exists (
  select 1 from public.chicken_data_shares share
  where share.owner_id = expenses.user_id
    and share.viewer_id = (select auth.uid())
));

create policy "shared viewer select" on public.cock_sales
for select to authenticated using (exists (
  select 1 from public.chicken_data_shares share
  where share.owner_id = cock_sales.user_id
    and share.viewer_id = (select auth.uid())
));

create policy "shared viewer select" on public.batch_sales
for select to authenticated using (exists (
  select 1 from public.chicken_data_shares share
  where share.owner_id = batch_sales.user_id
    and share.viewer_id = (select auth.uid())
));

-- Resolving an email requires auth.users, so this is deliberately SECURITY
-- DEFINER. It authenticates the caller, can only create a share owned by that
-- caller, has an empty search_path, and is not executable by PUBLIC/anon.
create or replace function public.share_chicken_data(p_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id uuid := auth.uid();
  v_viewer_id uuid;
begin
  if v_owner_id is null then
    raise exception 'Authentication required';
  end if;

  select users.id into v_viewer_id
  from auth.users users
  where lower(users.email) = lower(trim(p_email))
  limit 1;

  if v_viewer_id is null then
    raise exception 'No registered account uses that email';
  end if;
  if v_viewer_id = v_owner_id then
    raise exception 'You cannot share data with yourself';
  end if;

  insert into public.chicken_data_shares (owner_id, viewer_id)
  values (v_owner_id, v_viewer_id)
  on conflict (owner_id, viewer_id) do nothing;

  return v_viewer_id;
end;
$$;

-- Only relationship participants can discover these email addresses.
create or replace function public.get_chicken_data_sources()
returns table (owner_id uuid, owner_email text, is_owner boolean)
language sql
security definer
stable
set search_path = ''
as $$
  select users.id, users.email::text, users.id = auth.uid()
  from auth.users users
  where auth.uid() is not null
    and (
      users.id = auth.uid()
      or exists (
        select 1 from public.chicken_data_shares share
        where share.owner_id = users.id
          and share.viewer_id = auth.uid()
      )
    )
  order by users.id <> auth.uid(), lower(users.email);
$$;

create or replace function public.get_chicken_share_viewers()
returns table (viewer_id uuid, viewer_email text, created_at timestamptz)
language sql
security definer
stable
set search_path = ''
as $$
  select users.id, users.email::text, share.created_at
  from public.chicken_data_shares share
  join auth.users users on users.id = share.viewer_id
  where auth.uid() is not null and share.owner_id = auth.uid()
  order by share.created_at, lower(users.email);
$$;

create or replace function public.revoke_chicken_share(p_viewer_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.chicken_data_shares
  where owner_id = auth.uid() and viewer_id = p_viewer_id;
$$;

-- Shared reads are separate endpoints so existing clients keep their current
-- owner-only payload. Explicit owner filters prevent datasets from different
-- people being mixed when a viewer has access to more than one owner.
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
            'note', e.note
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
            'category', s.category
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
            'note', s.note
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
      'category', s.category
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
      'note', e.note
    ) order by e.date desc, e.created_at desc)
    from public.expenses e
    where e.user_id = p_owner_id and e.batch_id is null
      and (p_year is null or extract(year from e.date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;

create or replace function public.get_shared_chicken_years(p_owner_id uuid)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'batches', coalesce((
      select jsonb_agg(distinct extract(year from b.incubation_date)::int)
      from public.chicken_batches b where b.user_id = p_owner_id
    ), '[]'::jsonb),
    'global_cock_sales', coalesce((
      select jsonb_agg(distinct extract(year from s.date)::int)
      from public.cock_sales s
      where s.user_id = p_owner_id and s.batch_id is null
    ), '[]'::jsonb),
    'global_expenses', coalesce((
      select jsonb_agg(distinct extract(year from e.date)::int)
      from public.expenses e
      where e.user_id = p_owner_id and e.batch_id is null
    ), '[]'::jsonb)
  );
$$;

-- Once shared SELECT policies exist, the old unscoped endpoints would
-- otherwise combine the caller's records with every dataset shared to them.
-- Keep their original "my data" meaning for older app versions too.
create or replace function public.get_chicken_batches(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select public.get_shared_chicken_batches(auth.uid(), p_year);
$$;

create or replace function public.get_global_cock_sales(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select public.get_shared_global_cock_sales(auth.uid(), p_year);
$$;

create or replace function public.get_global_expenses(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select public.get_shared_global_expenses(auth.uid(), p_year);
$$;

create or replace function public.get_chicken_years()
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select public.get_shared_chicken_years(auth.uid());
$$;

revoke execute on function public.share_chicken_data(text) from public, anon;
revoke execute on function public.get_chicken_data_sources() from public, anon;
revoke execute on function public.get_chicken_share_viewers() from public, anon;
revoke execute on function public.revoke_chicken_share(uuid) from public, anon;
revoke execute on function public.get_shared_chicken_batches(uuid, int) from public, anon;
revoke execute on function public.get_shared_global_cock_sales(uuid, int) from public, anon;
revoke execute on function public.get_shared_global_expenses(uuid, int) from public, anon;
revoke execute on function public.get_shared_chicken_years(uuid) from public, anon;
revoke execute on function public.get_chicken_batches(int) from public, anon;
revoke execute on function public.get_global_cock_sales(int) from public, anon;
revoke execute on function public.get_global_expenses(int) from public, anon;
revoke execute on function public.get_chicken_years() from public, anon;

grant execute on function public.share_chicken_data(text) to authenticated;
grant execute on function public.get_chicken_data_sources() to authenticated;
grant execute on function public.get_chicken_share_viewers() to authenticated;
grant execute on function public.revoke_chicken_share(uuid) to authenticated;
grant execute on function public.get_shared_chicken_batches(uuid, int) to authenticated;
grant execute on function public.get_shared_global_cock_sales(uuid, int) to authenticated;
grant execute on function public.get_shared_global_expenses(uuid, int) to authenticated;
grant execute on function public.get_shared_chicken_years(uuid) to authenticated;
grant execute on function public.get_chicken_batches(int) to authenticated;
grant execute on function public.get_global_cock_sales(int) to authenticated;
grant execute on function public.get_global_expenses(int) to authenticated;
grant execute on function public.get_chicken_years() to authenticated;
