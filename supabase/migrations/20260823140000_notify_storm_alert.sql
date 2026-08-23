-- Ba cột này là bộ nhớ chống spam của cảnh báo bão: cron chạy 3 giờ một lần
-- nhưng một cơn bão kéo dài nhiều ngày, nên `summarize-storm-news` chỉ đẩy
-- notification khi có cơn bão mới, khi mức độ tăng lên, hoặc khi lần đẩy trước
-- đã quá một ngày.
alter table public.storm_news
  add column notified_at timestamptz,
  add column notified_name text,
  add column notified_severity text;
