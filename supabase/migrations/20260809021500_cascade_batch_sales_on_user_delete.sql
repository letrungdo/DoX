-- batch_sales.user_id was the one reference to auth.users created without
-- `on delete cascade`. Every other table cascades, so deleting an account used
-- to fail on this constraint alone once the user had recorded a single sale —
-- which is exactly the account most likely to want deleting.

alter table public.batch_sales
  drop constraint if exists batch_sales_user_id_fkey;

alter table public.batch_sales
  add constraint batch_sales_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;
