-- The scheduled Edge Functions stop trusting whoever holds the publishable key.
--
-- That key ships inside the app, so anyone could call these functions with it
-- and make them run with the service role: each call burns an AI request or a
-- few hundred requests to other people's CDNs, and rewrites a table the app
-- reads. The jobs now send a shared secret as `x-cron-secret` instead, and the
-- functions refuse anything else (`functions/_shared/cron_auth.ts`).
--
-- Like `chicken_notify_secret`, the secret is generated here so it is never
-- committed, and only created if it does not exist yet. Each job reads it from
-- Vault when it fires, so rotating the secret needs no new migration.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'cron_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'cron_secret',
      'Shared secret between the pg_cron jobs and the scheduled Edge Functions'
    );
  end if;
end;
$$;

-- Only the command changes; every job keeps the schedule it already has.
do $$
declare
  v_job record;
begin
  for v_job in
    select *
      from (values
        ('fetch-gold-price-periodic', 'fetch-gold-price', 120000),
        ('summarize-gold-news-daily', 'summarize-gold-news', 120000),
        ('summarize-storm-news', 'summarize-storm-news', 120000),
        ('refresh-tv-channels', 'refresh-tv-channels', 600000)
      ) as jobs (jobname, function_name, timeout_ms)
  loop
    perform cron.alter_job(
      (select jobid from cron.job where jobname = v_job.jobname),
      command := format(
        $cmd$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/%s',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (
        select decrypted_secret from vault.decrypted_secrets
         where name = 'cron_secret'
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := %s
  );
  $cmd$,
        v_job.function_name,
        v_job.timeout_ms
      )
    );
  end loop;
end;
$$;
