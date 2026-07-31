-- Inserts a chicken batch together with all of its children in one
-- transaction, so a failure part-way through can no longer leave a batch row
-- behind without its vaccinations/expenses/sales (PostgREST gives the client
-- no way to group the separate inserts).
--
-- SECURITY INVOKER (the default): row level security still applies with the
-- caller's auth.uid(), and user_id keeps defaulting to it on every table.
create or replace function public.insert_chicken_batch(
  p_batch jsonb,
  p_vaccinations jsonb default '[]'::jsonb,
  p_expenses jsonb default '[]'::jsonb,
  p_cock_sales jsonb default '[]'::jsonb,
  p_batch_sales jsonb default '[]'::jsonb
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid := (p_batch->>'id')::uuid;
begin
  insert into public.chicken_batches (
    id, name, incubation_date, quantity, actual_hatch_date
  )
  values (
    v_batch_id,
    p_batch->>'name',
    (p_batch->>'incubation_date')::date,
    (p_batch->>'quantity')::int,
    nullif(p_batch->>'actual_hatch_date', '')::date
  );

  insert into public.vaccinations (
    id, batch_id, title, scheduled_date, is_completed
  )
  select
    (e->>'id')::uuid,
    v_batch_id,
    e->>'title',
    (e->>'scheduled_date')::date,
    coalesce((e->>'is_completed')::boolean, false)
  from jsonb_array_elements(coalesce(p_vaccinations, '[]'::jsonb)) e;

  insert into public.expenses (id, batch_id, type, amount, date, note)
  select
    (e->>'id')::uuid,
    v_batch_id,
    e->>'type',
    (e->>'amount')::double precision,
    (e->>'date')::date,
    e->>'note'
  from jsonb_array_elements(coalesce(p_expenses, '[]'::jsonb)) e;

  insert into public.cock_sales (id, batch_id, note, amount, date, category)
  select
    (e->>'id')::uuid,
    v_batch_id,
    coalesce(e->>'note', ''),
    (e->>'amount')::double precision,
    (e->>'date')::date,
    coalesce(e->>'category', 'fighting')
  from jsonb_array_elements(coalesce(p_cock_sales, '[]'::jsonb)) e;

  insert into public.batch_sales (id, batch_id, date, quantity, amount, note)
  select
    (e->>'id')::uuid,
    v_batch_id,
    (e->>'date')::date,
    coalesce((e->>'quantity')::int, 0),
    (e->>'amount')::double precision,
    e->>'note'
  from jsonb_array_elements(coalesce(p_batch_sales, '[]'::jsonb)) e;
end;
$$;

revoke execute on function public.insert_chicken_batch(jsonb, jsonb, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.insert_chicken_batch(jsonb, jsonb, jsonb, jsonb, jsonb) to authenticated;;
