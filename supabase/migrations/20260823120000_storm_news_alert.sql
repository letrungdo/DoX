-- Bản tin bão do AI tổng hợp, cùng khuôn với `gold_news`: đúng một dòng, mỗi
-- lượt chạy ghi đè lên dòng cũ. Khác một điểm: bão không phải lúc nào cũng có,
-- nên `active` cho biết hiện có bão/áp thấp đang ảnh hưởng Việt Nam hay không.
-- App chỉ hiện thẻ khi `active` = true, ngoài ra bảng vẫn giữ dòng đó để lần
-- chạy sau biết bản tin đã được cập nhật lúc nào.
create table public.storm_news (
  id smallint primary key default 1,
  constraint storm_news_single_row check (id = 1),
  date date not null,
  active boolean not null default false,
  name_vi text,
  name_en text,
  severity text not null default 'watch'
    check (severity in ('watch', 'warning', 'emergency')),
  headline_vi text,
  headline_en text,
  summary_vi text,
  summary_en text,
  advice_vi text,
  advice_en text,
  highlights jsonb not null default '[]'::jsonb,
  sources jsonb not null default '[]'::jsonb,
  model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.storm_news enable row level security;

create policy "public read" on public.storm_news
  for select to anon, authenticated using (true);

-- Bão diễn biến theo giờ chứ không theo ngày, nên chạy 3 giờ một lần.
select cron.schedule(
  'summarize-storm-news',
  '10 */3 * * *',
  $$
  select net.http_post(
    url := 'https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/summarize-storm-news',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
