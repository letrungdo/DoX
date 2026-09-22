-- The channel list is rebuilt every other day instead of every Monday.
--
-- A week is a long time for a link to be dead. The spare URLs cover a stream
-- that dies mid-week, but only until they die too, and nothing new reaches
-- the app before the next Monday — a channel the sources fixed on Tuesday
-- stays broken for six days.
--
-- Every other day rather than nightly, because the run costs a few hundred
-- requests to other people's CDNs and the upstream playlists barely change
-- from one day to the next. `*/2` fires on the odd days of the month, which
-- is a two day gap everywhere but the turn of a 31 day month. Still 03:00
-- ICT (20:00 UTC), since the run takes minutes and nobody is watching then.
do $$
declare
  v_jobid bigint;
begin
  -- The old job named itself after its schedule, so it is replaced rather
  -- than altered.
  select jobid into v_jobid
    from cron.job
   where jobname = 'refresh-tv-channels-weekly';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end;
$$;

select cron.schedule(
  'refresh-tv-channels',
  '0 20 */2 * *',
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
