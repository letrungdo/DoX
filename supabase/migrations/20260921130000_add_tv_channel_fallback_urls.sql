-- The spare links of a channel.
--
-- A live stream dies without warning and without saying so: the CDN keeps
-- serving a perfectly good manifest and simply stops writing segments behind
-- it, so the picture never starts and the player is never told why. Until now
-- a channel carried the one link the weekly run saw playing, which meant a
-- link that died on Tuesday left the channel broken until the following
-- Monday.
--
-- The run already gathers several links per station — the catalogue's and
-- whatever the community collection adds — and stops checking at the first
-- one that plays. The rest were thrown away. They are kept here instead, and
-- the app works down them when the one in front of it will not come up.
alter table public.tv_channels
  add column urls text[] not null default '{}';

comment on column public.tv_channels.urls is
  'Every stream known for the channel, the one last seen playing first.';

-- Existing rows have the one link they were written with.
update public.tv_channels set urls = array[url] where cardinality(urls) = 0;

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
    country_code, slug, name, url, urls, logo, categories, quality,
    is_geo_blocked, is_intermittent, headers, sort_order, checked_at
  )
  select
    p_country,
    row_value ->> 'slug',
    row_value ->> 'name',
    row_value ->> 'url',
    -- A run written before this column existed sends no `urls`; the one link
    -- it does send is then the whole list.
    coalesce(
      nullif(array(select jsonb_array_elements_text(row_value -> 'urls')), '{}'),
      array[row_value ->> 'url']
    ),
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

revoke all on function public.replace_tv_channels(text, jsonb) from public;
revoke all on function public.replace_tv_channels(text, jsonb) from anon;
revoke all on function public.replace_tv_channels(text, jsonb) from authenticated;
grant execute on function public.replace_tv_channels(text, jsonb) to service_role;
