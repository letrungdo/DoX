-- The Vietnamese channel list the TV page shows, rebuilt weekly by the
-- `refresh-tv-channels` Edge Function.
--
-- The app used to assemble this itself: download two playlists, throw out the
-- entries that are not channels, fold the stations each list spells its own
-- way into one, and find out the hard way which links are dead. That is a lot
-- of work to repeat on every phone, and the part that matters most — whether
-- a stream actually plays — is the part a phone is worst at, because it can
-- only learn it by making someone sit through a channel that never starts.
--
-- So the work happens here, once a week, and the app reads the answer.
create table public.tv_channels (
  country_code text not null,
  -- Identity of the station rather than of the link, so a channel keeps its
  -- row when the playlists change which URL they carry for it.
  slug text not null,
  name text not null,
  url text not null,
  logo text,
  -- The iptv-org category vocabulary, which is what the app's filter chips
  -- are written against. A channel is often filed under several, and empty
  -- for one nothing is known about.
  categories text[] not null default '{}',
  quality text,
  is_geo_blocked boolean not null default false,
  is_intermittent boolean not null default false,
  -- The `Referer` / `User-Agent` some CDNs want before they hand the stream
  -- over, as `{header: value}`.
  headers jsonb not null default '{}'::jsonb,
  -- Display order, worked out here so the app draws the rows as they come.
  -- Not `position`: that is a SQL keyword, and a column named after one is a
  -- surprise waiting in whichever query forgets to quote it.
  sort_order integer not null,
  -- When this channel was last seen playing.
  checked_at timestamptz not null default now(),
  primary key (country_code, slug)
);

create index tv_channels_country_order_idx
  on public.tv_channels (country_code, sort_order);

alter table public.tv_channels enable row level security;

create policy "public read" on public.tv_channels
  for select to anon, authenticated using (true);

-- Swaps a country's whole list in one transaction.
--
-- The refresh is all-or-nothing on purpose: a delete followed by an insert
-- from the function would leave the table empty for as long as the insert
-- takes, and a phone opening the page in that window would be told Vietnam
-- has no television.
create or replace function public.replace_tv_channels(
  p_country text,
  p_rows jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  -- An empty result is a failed run, not a country that went off the air, so
  -- it must never be allowed to wipe a list that was working.
  if p_rows is null or jsonb_array_length(p_rows) = 0 then
    raise exception 'replace_tv_channels: refusing to empty %', p_country;
  end if;

  delete from public.tv_channels where country_code = p_country;

  insert into public.tv_channels (
    country_code, slug, name, url, logo, categories, quality,
    is_geo_blocked, is_intermittent, headers, sort_order, checked_at
  )
  select
    p_country,
    row_value ->> 'slug',
    row_value ->> 'name',
    row_value ->> 'url',
    row_value ->> 'logo',
    -- A missing or empty `categories` yields no rows, and `array()` over no
    -- rows is already the empty array the column wants.
    array(select jsonb_array_elements_text(row_value -> 'categories')),
    row_value ->> 'quality',
    coalesce((row_value -> 'is_geo_blocked')::boolean, false),
    coalesce((row_value -> 'is_intermittent')::boolean, false),
    coalesce(row_value -> 'headers', '{}'::jsonb),
    (row_value ->> 'sort_order')::integer,
    now()
  from jsonb_array_elements(p_rows) as row_value;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Only the refresh job writes the list. The function runs as its owner, so
-- leaving the default grant in place would let any signed-in phone replace
-- the country's television.
revoke all on function public.replace_tv_channels(text, jsonb) from public;
revoke all on function public.replace_tv_channels(text, jsonb) from anon;
revoke all on function public.replace_tv_channels(text, jsonb) from authenticated;
grant execute on function public.replace_tv_channels(text, jsonb) to service_role;

-- Rebuild the list every Monday at 03:00 ICT (Sunday 20:00 UTC).
--
-- Weekly rather than nightly: the upstream playlists are rebuilt daily but
-- barely change, and the run costs a few hundred requests to other people's
-- CDNs. Early Monday because the run takes minutes and nobody is watching.
select cron.schedule(
  'refresh-tv-channels-weekly',
  '0 20 * * 0',
  $$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/refresh-tv-channels',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 600000
  );
  $$
);
