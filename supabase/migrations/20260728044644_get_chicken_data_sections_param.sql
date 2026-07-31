-- Adds a section filter so a screen only pays for what it shows: the cock-sale
-- screen no longer downloads every batch, and so on. Passing null (or omitting
-- the argument) still returns everything, which is what the statistics screen
-- and the post-sync refresh want.
--
-- A section that was not asked for is absent from the object rather than empty,
-- so the client can tell "you did not ask" from "there is nothing there".
create or replace function public.get_chicken_data(p_sections text[] default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce(
    case when p_sections is null or 'batches' = any(p_sections) then
      jsonb_build_object('batches', coalesce((
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
      ), '[]'::jsonb))
    else '{}'::jsonb end
    ||
    case when p_sections is null or 'global_cock_sales' = any(p_sections) then
      jsonb_build_object('global_cock_sales', coalesce((
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
      ), '[]'::jsonb))
    else '{}'::jsonb end
    ||
    case when p_sections is null or 'global_expenses' = any(p_sections) then
      jsonb_build_object('global_expenses', coalesce((
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
      ), '[]'::jsonb))
    else '{}'::jsonb end,
    '{}'::jsonb
  );
$$;

revoke execute on function public.get_chicken_data(text[]) from public, anon;
grant execute on function public.get_chicken_data(text[]) to authenticated;;
