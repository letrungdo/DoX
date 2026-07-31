-- Single read endpoint for the chicken tab: batches with their children plus
-- the batch-less (global) sales and expenses, in one round trip instead of
-- three. The client no longer names tables or spells out embeds, so the shape
-- of the payload is a contract the schema can move underneath.
--
-- SECURITY INVOKER (the default): every table read still goes through row
-- level security as the calling user.
create or replace function public.get_chicken_data()
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'batches', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'name', b.name,
          'incubation_date', b.incubation_date,
          'quantity', b.quantity,
          'actual_hatch_date', b.actual_hatch_date,
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
    ), '[]'::jsonb),
    'global_cock_sales', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'note', s.note,
          'amount', s.amount,
          'date', s.date,
          'category', s.category
        ) order by s.date desc, s.created_at desc
      )
      from public.cock_sales s
      where s.batch_id is null
    ), '[]'::jsonb),
    'global_expenses', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'type', e.type,
          'amount', e.amount,
          'date', e.date,
          'note', e.note
        ) order by e.date desc, e.created_at desc
      )
      from public.expenses e
      where e.batch_id is null
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.get_chicken_data() from public, anon;
grant execute on function public.get_chicken_data() to authenticated;;
