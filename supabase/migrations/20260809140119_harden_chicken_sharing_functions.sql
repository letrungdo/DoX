-- Keep privileged auth.users lookups out of the exposed public schema. Public
-- RPCs remain SECURITY INVOKER and delegate to narrowly granted private
-- functions that validate auth.uid() before reading or writing anything.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.share_chicken_data(p_email text)
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

create or replace function private.get_chicken_data_sources()
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

create or replace function private.get_chicken_share_viewers()
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

revoke execute on function private.share_chicken_data(text) from public, anon;
revoke execute on function private.get_chicken_data_sources() from public, anon;
revoke execute on function private.get_chicken_share_viewers() from public, anon;
grant execute on function private.share_chicken_data(text) to authenticated;
grant execute on function private.get_chicken_data_sources() to authenticated;
grant execute on function private.get_chicken_share_viewers() to authenticated;

create or replace function public.share_chicken_data(p_email text)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.share_chicken_data(p_email);
$$;

create or replace function public.get_chicken_data_sources()
returns table (owner_id uuid, owner_email text, is_owner boolean)
language sql
security invoker
stable
set search_path = ''
as $$
  select * from private.get_chicken_data_sources();
$$;

create or replace function public.get_chicken_share_viewers()
returns table (viewer_id uuid, viewer_email text, created_at timestamptz)
language sql
security invoker
stable
set search_path = ''
as $$
  select * from private.get_chicken_share_viewers();
$$;

revoke execute on function public.share_chicken_data(text) from public, anon;
revoke execute on function public.get_chicken_data_sources() from public, anon;
revoke execute on function public.get_chicken_share_viewers() from public, anon;
grant execute on function public.share_chicken_data(text) to authenticated;
grant execute on function public.get_chicken_data_sources() to authenticated;
grant execute on function public.get_chicken_share_viewers() to authenticated;
