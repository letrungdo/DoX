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

`severity` (`watch` / `warning` / `emergency`) để app chọn màu thẻ (xanh → cam
→ đỏ) và làm tiền tố tiêu đề notification.

## Notification

Có bão thì function đẩy push tới **mọi** dòng trong `device_tokens` (bão thì ai
cũng cần biết, không chỉ người được chia sẻ dữ liệu gà), nội dung theo `locale`
của từng device, `data.type = "storm_news"` để app mở tab Tin tức khi bấm vào.

Cron chạy 3 giờ một lần mà bão thì kéo dài nhiều ngày, nên `shouldNotify` chỉ
đẩy khi người đọc có cái mới để biết:

- cơn bão khác với cơn đã báo (`notified_name`), hoặc
- mức độ nặng hơn lần báo trước (`notified_severity`), hoặc
- vẫn cơn đó nhưng lần báo trước đã hơn 24 giờ (`notified_at`).

Ba cột `notified_*` chỉ được ghi khi thật sự đẩy push, nên một lượt chạy im
lặng không reset đồng hồ chống spam. Push lỗi thì chỉ ghi log, bản tin vẫn được
lưu. Token bị FCM từ chối hẳn (404/400) thì bị xoá khỏi `device_tokens`.

Phần gọi FCM nằm ở [`../_shared/fcm.ts`](../_shared/fcm.ts), dùng chung với
`notify-chicken-activity` — sửa file đó thì deploy lại cả hai function. Cần
secret `FCM_SERVICE_ACCOUNT` (đã có sẵn nếu push dữ liệu gà đang chạy).

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
supabase functions deploy summarize-gold-news      # dùng chung _shared/news_feed.ts
supabase functions deploy notify-chicken-activity  # dùng chung _shared/fcm.ts
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
