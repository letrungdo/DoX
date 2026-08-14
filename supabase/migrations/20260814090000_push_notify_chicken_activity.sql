-- Push notifications for the people a chicken dataset is shared with.
--
-- A viewer only ever reads the owner's data, so nothing tells them the numbers
-- moved. These triggers turn every new sale or expense into one push per
-- statement, delivered by the `notify-chicken-activity` Edge Function.

-- Devices that may receive a push, one row per FCM registration token. The
-- token is the primary key because it identifies a device install, not a user:
-- signing in as somebody else on the same phone must move the token, not
-- duplicate it.
create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  locale text not null default 'vi',
  updated_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

-- Reading their own devices is all a client needs; registration and removal go
-- through the functions below, which also have to clear a token another account
-- left on this device.
create policy "owner select" on public.device_tokens
for select to authenticated using ((select auth.uid()) = user_id);

create policy "owner delete" on public.device_tokens
for delete to authenticated using ((select auth.uid()) = user_id);

grant select, delete on public.device_tokens to authenticated;

-- SECURITY DEFINER so the same physical device can be handed from one account
-- to the next: the previous owner's row has to go, and the caller has no rights
-- over it. The caller still cannot register a token for anybody but themselves.
create or replace function public.register_device_token(
  p_token text,
  p_platform text,
  p_locale text default 'vi'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if coalesce(trim(p_token), '') = '' then
    raise exception 'A device token is required';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Unsupported platform';
  end if;

  insert into public.device_tokens (token, user_id, platform, locale)
  values (trim(p_token), v_user_id, p_platform, coalesce(p_locale, 'vi'))
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        locale = excluded.locale,
        updated_at = now();
end;
$$;

-- Signing out removes the token whoever it currently belongs to: the device is
-- in the hands of the person calling this, and leaving the row behind would
-- keep pushing somebody else's data to it.
create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_tokens where token = trim(p_token);
$$;

revoke execute on function public.register_device_token(text, text, text)
  from public, anon;
revoke execute on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text, text)
  to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- The Edge Function is called with a shared secret rather than a session: the
-- statement that fires this has no user token to forward, and the function has
-- to read other people's device tokens. The secret is generated here so it is
-- never committed, and only replaced if it does not exist yet.
do $$
begin
  if not exists (
    select 1 from vault.secrets where name = 'chicken_notify_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'chicken_notify_secret',
      'Shared secret between the chicken activity triggers and the notify-chicken-activity Edge Function'
    );
  end if;
end;
$$;

-- Statement level with a transition table, not row level: adding a batch
-- inserts all of its sales in one statement, and a viewer wants "3 gà đã bán",
-- not three notifications.
create or replace function public.notify_chicken_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_row record;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'chicken_notify_secret';
  -- No secret configured means notifications are off; the write still stands.
  if v_secret is null then
    return null;
  end if;

  for v_row in
    select user_id, count(*)::int as row_count, coalesce(sum(amount), 0) as total
    from new_rows
    group by user_id
  loop
    continue when not exists (
      select 1 from public.chicken_data_shares
      where owner_id = v_row.user_id
    );

    perform net.http_post(
      url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/notify-chicken-activity',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notify-secret', v_secret
      ),
      body := jsonb_build_object(
        'owner_id', v_row.user_id,
        'kind', tg_argv[0],
        'count', v_row.row_count,
        'total', v_row.total
      ),
      timeout_milliseconds := 10000
    );
  end loop;

  return null;
end;
$$;

revoke execute on function public.notify_chicken_activity() from public, anon, authenticated;

create trigger notify_cock_sale_insert
after insert on public.cock_sales
referencing new table as new_rows
for each statement
execute function public.notify_chicken_activity('cock_sale');

create trigger notify_batch_sale_insert
after insert on public.batch_sales
referencing new table as new_rows
for each statement
execute function public.notify_chicken_activity('batch_sale');

create trigger notify_expense_insert
after insert on public.expenses
referencing new table as new_rows
for each statement
execute function public.notify_chicken_activity('expense');
