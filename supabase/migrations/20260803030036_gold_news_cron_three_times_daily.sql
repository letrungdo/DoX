-- 06:00 / 12:00 / 18:00 Vietnam time = 23:00 (previous UTC day) / 05:00 / 11:00 UTC.
select cron.alter_job(
  (select jobid from cron.job where jobname = 'summarize-gold-news-daily'),
  schedule := '0 23,5,11 * * *'
);;
