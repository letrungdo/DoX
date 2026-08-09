-- The app ships in Vietnamese and English, so the digest is written in both
-- languages in the same Gemini call. Language-neutral parts (sentiment,
-- impact, sources) stay shared.
alter table public.gold_news rename column summary to summary_vi;
alter table public.gold_news rename column sentiment_reason to sentiment_reason_vi;

alter table public.gold_news
  add column summary_en text not null default '',
  add column sentiment_reason_en text;

-- The stored digest predates the English columns; the next run overwrites it.
delete from public.gold_news;;
