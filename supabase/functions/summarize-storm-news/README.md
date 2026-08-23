# summarize-storm-news

Cảnh báo bão do AI tổng hợp, cùng khuôn với [`summarize-gold-news`](../summarize-gold-news/README.md):
gom tiêu đề 30 giờ gần nhất từ RSS (Google News VN/EN, VnExpress, Tuổi Trẻ),
nhờ Gemini xác định có bão/áp thấp nhiệt đới đang (hoặc sắp trong ~3 ngày) ảnh
hưởng Việt Nam hay không, rồi ghi đúng một dòng `storm_news`. App chỉ đọc bảng.

Khác bản tin vàng ở chỗ **thường là không có gì để hiện**: khi không có bão,
dòng đó được ghi với `active = false` và mọi cột văn bản để `null`, app không
vẽ thẻ nào cả. App còn bỏ qua bản tin quá 12 giờ chưa cập nhật — một cảnh báo
không ai làm mới còn tệ hơn không cảnh báo.

Nếu **mọi** feed đều lỗi thì function trả 502 chứ không ghi `active = false`:
"không đọc được tin" không đồng nghĩa với "không có bão".

`severity` (`watch` / `warning` / `emergency`) chỉ để app chọn màu thẻ, từ xanh
sang cam sang đỏ.

Phần đọc RSS, gọi Gemini và gỡ link bọc `news.google.com` nằm ở
[`../_shared/news_feed.ts`](../_shared/news_feed.ts), dùng chung với bản tin
vàng — sửa file đó thì deploy lại cả hai function.

Cron `summarize-storm-news` chạy 3 giờ một lần (`10 */3 * * *` UTC); bản tin
mới dưới 2 giờ thì function trả về luôn, không gọi Gemini.

## Triển khai

```bash
supabase secrets set GEMINI_API_KEY=xxx      # đã có sẵn nếu bản tin vàng đang chạy
supabase db push                              # bảng + cron
supabase functions deploy summarize-storm-news
supabase functions deploy summarize-gold-news  # vì dùng chung _shared/news_feed.ts
```

## Chạy thử

```bash
curl -X POST "https://fyyrgwohjgvsmwqgxiga.supabase.co/functions/v1/summarize-storm-news" \
  -H "Authorization: Bearer <publishable_key>"
```

Muốn ép chạy lại sớm hơn 2 giờ:

```sql
delete from public.storm_news;
```

## Thêm / bớt nguồn

Sửa mảng `FEEDS` trong `index.ts`. Feed chuyên đề (search query đã nhắm đúng
chủ đề) đặt `filter: false`; feed thời sự chung đặt `filter: true` để lọc theo
`KEYWORDS` trước khi gửi cho Gemini.
