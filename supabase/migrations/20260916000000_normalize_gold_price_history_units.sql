-- Snapshots written before the price parser was fixed stored the price in
-- millions of VND ("142.3") instead of VND ("142300000"). The day-change is a
-- subtraction between two snapshots, so mixing the two units produced changes
-- of ~143 million. Rewrite the legacy rows into VND; every genuine gold price
-- is far above 1,000,000 VND per tael, so the threshold is unambiguous.
update public.gold_price_history
set bid = bid * 1000000,
    ask = ask * 1000000
where bid < 1000000;

-- gold_prices.*_change is recomputed from scratch on the next fetch; clear the
-- garbage so nothing shows a bogus change in the meantime.
update public.gold_prices
set bid_change = 0,
    ask_change = 0;
