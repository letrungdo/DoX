-- A crypto holding's cost is paid in đồng, so the rate it was bought at is part
-- of what it cost. Without it every holding is valued at today's rate on both
-- sides, which cancels the currency out: a USDT balance bought at 24,000 and
-- worth 27,000 today reported no gain at all.
--
-- Null means the rate was never recorded, and those rows keep falling back to
-- today's rate, exactly as they did before this column existed.
alter table public.asset_investments
    add column if not exists buy_fx_rate double precision;

comment on column public.asset_investments.buy_fx_rate is
    'VND per USDT on the day the holding was bought.';
