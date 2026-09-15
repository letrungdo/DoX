-- Add dead_quantity and kept_quantity to chicken_batches table
alter table public.chicken_batches
add column dead_quantity int not null default 0,
add column kept_quantity int not null default 0;

-- Update insert_chicken_batch function to include new fields
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
    id, name, incubation_date, quantity, actual_hatch_date, dead_quantity, kept_quantity
  )
  values (
    v_batch_id,
    p_batch->>'name',
    (p_batch->>'incubation_date')::date,
    (p_batch->>'quantity')::int,
    nullif(p_batch->>'actual_hatch_date', '')::date,
    coalesce((p_batch->>'dead_quantity')::int, 0),
    coalesce((p_batch->>'kept_quantity')::int, 0)
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

-- Update get_chicken_batches function to include new fields
create or replace function public.get_chicken_batches(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'name', b.name,
        'incubation_date', b.incubation_date,
        'quantity', b.quantity,
        'actual_hatch_date', b.actual_hatch_date,
        'dead_quantity', b.dead_quantity,
        'kept_quantity', b.kept_quantity,
        'vaccinations', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', v.id,
              'title', v.title,
              'scheduled_date', v.scheduled_date,
              'is_completed', v.is_completed
            ) order by v.scheduled_date
          )
          from public.vaccinations v
          where v.batch_id = b.id
        ), '[]'::jsonb),
        'expenses', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', e.id,
              'type', e.type,
              'amount', e.amount,
              'date', e.date,
              'note', e.note
            ) order by e.date, e.created_at
          )
          from public.expenses e
          where e.batch_id = b.id
        ), '[]'::jsonb),
        'cock_sales', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', s.id,
              'note', s.note,
              'amount', s.amount,
              'date', s.date,
              'category', s.category
            ) order by s.date, s.created_at
          )
          from public.cock_sales s
          where s.batch_id = b.id
        ), '[]'::jsonb),
        'batch_sales', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', s.id,
              'date', s.date,
              'quantity', s.quantity,
              'amount', s.amount,
              'note', s.note
            ) order by s.date
          )
          from public.batch_sales s
          where s.batch_id = b.id
        ), '[]'::jsonb)
      ) order by b.incubation_date desc, b.created_at desc
    )
    from public.chicken_batches b
    where p_year is null
       or extract(year from b.incubation_date) between p_year - 1 and p_year
  ), '[]'::jsonb);
$$;
