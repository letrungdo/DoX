-- Two fixes found by looking at what the jobs actually did.
--
-- 1. A second try for the news digests. Gemini answers 503 "high demand" in
--    bursts that outlast the in-function retries (three attempts over ~15s):
--    on 2026-09-23 it cost the 06:00 gold digest, which then stayed a day old
--    until noon, and one storm bulletin. Each job now also fires 30 minutes
--    later. When the first run worked, the second finds the row fresher than
--    MIN_REBUILD_AGE_MS and returns before touching Gemini, so the extra slot
--    costs one cheap invocation.
select cron.alter_job(
  (select jobid from cron.job where jobname = 'summarize-gold-news-daily'),
  schedule := '0,30 23,5,11 * * *'
);

select cron.alter_job(
  (select jobid from cron.job where jobname = 'summarize-storm-news'),
  schedule := '10,40 */3 * * *'
);

-- 2. pg_cron keeps a row per run forever. The old every-minute fx job alone
--    left ~85k of them (28 MB) behind. Keep a week, which is plenty to see
--    what went wrong, and prune nightly at 03:30 Vietnam time (20:30 UTC).
delete from cron.job_run_details where end_time < now() - interval '7 days';

select cron.schedule(
  'prune-cron-history',
  '30 20 * * *',
  $$
  delete from cron.job_run_details where end_time < now() - interval '7 days';
  $$
);
