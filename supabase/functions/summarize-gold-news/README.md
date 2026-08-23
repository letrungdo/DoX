# summarize-gold-news

Bản tin hằng ngày về các tin ảnh hưởng giá vàng: gom tiêu đề 48h gần nhất từ
nhiều nguồn RSS (Google News VN/EN, VnExpress, CafeF), nhờ Gemini lọc + tóm tắt
tiếng Việt, rồi ghi đúng một dòng `gold_news` cho ngày hôm đó. App chỉ đọc bảng.

Model mặc định `gemini-3.6-flash`, đổi được bằng secret `GEMINI_MODEL`.

Mỗi đoạn văn bản được viết sẵn cả tiếng Việt lẫn tiếng Anh trong cùng một lượt
gọi Gemini (`summary_vi`/`summary_en`, `title_vi`/`title_en`, …), nên app đổi
ngôn ngữ là đổi nội dung ngay, không phải gọi lại server. Phần không phụ thuộc
ngôn ngữ (`sentiment`, `impact`, `sources`) chỉ lưu một lần.

Link trong `sources` đã được gỡ khỏi lớp bọc `news.google.com/rss/articles/...`
(trang đó chỉ chuyển hướng bằng JavaScript nên mở trong app là trắng trang):
hàm `resolveArticleUrl` lặp lại đúng lượt gọi `batchexecute` mà giao diện Google
News dùng để lấy địa chỉ thật. Nếu Google đổi cách làm thì link gốc được giữ
nguyên chứ bản tin không hỏng.

Phần đọc RSS, gọi Gemini và gỡ link bọc `news.google.com` nằm ở
[`../_shared/news_feed.ts`](../_shared/news_feed.ts), dùng chung với
[`summarize-storm-news`](../summarize-storm-news/README.md) — sửa file đó thì
deploy lại cả hai function.

Đã triển khai trên project `fyyrgwohjgvsmwqgxiga`: bảng + policy, cron
`summarize-gold-news-daily` (`0 23,5,11 * * *` UTC = 06:00 / 12:00 / 18:00 giờ
VN), secret `GEMINI_API_KEY`, và function này.

## Triển khai lại

```bash
supabase secrets set GEMINI_API_KEY=xxx      # https://aistudio.google.com/apikey
supabase db push                              # bảng + cron
supabase functions deploy summarize-gold-news
```

## Chạy thử

```bash
curl -X POST "https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/summarize-gold-news" \
  -H "Authorization: Bearer <publishable_key>"
```

Cron gọi bằng publishable key (đã public trong app) nên endpoint coi như ai
cũng gọi được. Hai chốt chặn khiến việc đó vô hại: chỉ ghi được ngày hôm nay
hoặc hôm qua (`?date=YYYY-MM-DD`), và nếu bản tin của ngày đó mới dưới 3 giờ
thì trả về luôn, không gọi Gemini. Muốn ép chạy lại sớm hơn thì xoá dòng đó:

```sql
delete from public.gold_news where date = current_date;
```

## Thêm / bớt nguồn

Sửa mảng `FEEDS` trong `index.ts`. Feed chuyên đề (search query đã nhắm đúng
chủ đề) đặt `filter: false`; feed kinh doanh chung đặt `filter: true` để lọc
theo `KEYWORDS` trước khi gửi cho Gemini.
