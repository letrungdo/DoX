-- Update get_shared_chicken_batches to include dead_quantity and kept_quantity fields
create or replace function public.get_shared_chicken_batches(
  p_owner_id uuid,
  p_year int default null
)
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
          select jsonb_agg(jsonb_build_object(
            'id', v.id,
            'title', v.title,
            'scheduled_date', v.scheduled_date,
            'is_completed', v.is_completed
          ) order by v.scheduled_date)
          from public.vaccinations v
          where v.batch_id = b.id and v.user_id = p_owner_id
        ), '[]'::jsonb),
        'expenses', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', e.id,
            'type', e.type,
            'amount', e.amount,
            'date', e.date,
            'note', e.note
          ) order by e.date, e.created_at)
          from public.expenses e
          where e.batch_id = b.id and e.user_id = p_owner_id
        ), '[]'::jsonb),
        'cock_sales', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', s.id,
            'note', s.note,
            'amount', s.amount,
            'date', s.date,
            'category', s.category
          ) order by s.date, s.created_at)
          from public.cock_sales s
          where s.batch_id = b.id and s.user_id = p_owner_id
        ), '[]'::jsonb),
        'batch_sales', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', s.id,
            'date', s.date,
            'quantity', s.quantity,
            'amount', s.amount,
            'note', s.note
          ) order by s.date)
          from public.batch_sales s
          where s.batch_id = b.id and s.user_id = p_owner_id
        ), '[]'::jsonb)
      ) order by b.incubation_date desc, b.created_at desc
    )
    from public.chicken_batches b
    where b.user_id = p_owner_id
      and (p_year is null
        or extract(year from b.incubation_date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;
