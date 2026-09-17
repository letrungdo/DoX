-- "Vàng nhẫn 9999 (Tư nhân)" is retired: a private jeweller's plain ring is
-- priced off the same PNJ quote as any other, so the separate type only made
-- the picker longer. Records keep their type by label, so move them across or
-- they would stop resolving to a price at all.
update public.asset_gold
set gold_type = 'Vàng nhẫn 9999'
where gold_type = 'Vàng nhẫn 9999 (Tư nhân)';
