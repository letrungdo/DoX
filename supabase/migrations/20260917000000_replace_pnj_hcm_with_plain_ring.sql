-- The PNJ tael quote for HCM is replaced by the plain ring "Nhẫn Trơn PNJ
-- 999.9", which PNJ publishes nationwide under its jewellery section. Drop the
-- retired row so the app stops showing a price nothing refreshes any more; the
-- new PNJ_RING_9999 row appears on the next fetch.
delete from public.gold_prices where code = 'PNJ_HCM';

-- gold_price_history keeps its PNJ_HCM snapshots: nothing reads a code the
-- fetcher no longer writes, and they are the only record of that series.
