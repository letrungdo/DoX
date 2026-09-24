-- `update-fx-rate` joins the other scheduled functions: it now refuses callers
-- without the Vault `cron_secret` (see 20260924013244), and its job finally
-- lives in a migration instead of only on the dashboard.
--
-- Every five minutes rather than every minute: the rates it reads move a few
-- times a day, and each run hits five outside services. Nothing runs between
-- 01:00 and 05:00 Vietnam time (18:00–21:59 UTC), when nobody is looking at
-- the rates — the last run is 00:55 and the first one back is 05:00.
do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname = 'update-fx-rate';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end;
$$;

select cron.schedule(
  'update-fx-rate',
  '*/5 0-17,22-23 * * *',
  $$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/update-fx-rate',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (
        select decrypted_secret from vault.decrypted_secrets
         where name = 'cron_secret'
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
