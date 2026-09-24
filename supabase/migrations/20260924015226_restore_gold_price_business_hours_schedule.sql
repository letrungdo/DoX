-- The gold price job had drifted to `*/30 * * * *` on the dashboard, running
-- around the clock. Put it back on the business hours 20260915100000
-- declared — Monday to Saturday, 08:00–20:45 ICT (01:00–13:45 UTC), when PNJ
-- actually moves its prices — but every 15 minutes instead of 30, so a price
-- change reaches the app sooner.
select cron.alter_job(
  (select jobid from cron.job where jobname = 'fetch-gold-price-periodic'),
  schedule := '*/15 1-13 * * 1-6'
);
