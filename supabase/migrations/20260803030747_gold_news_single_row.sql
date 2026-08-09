-- The app only ever reads the newest digest, so the table keeps exactly one
-- row: every run overwrites it instead of leaving a day-by-day history.
delete from public.gold_news
where date <> (select max(date) from public.gold_news);

alter table public.gold_news drop constraint gold_news_pkey;

alter table public.gold_news
  add column id smallint not null default 1,
  add constraint gold_news_single_row check (id = 1);

alter table public.gold_news add primary key (id);;
