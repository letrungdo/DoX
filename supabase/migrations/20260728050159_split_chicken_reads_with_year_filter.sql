-- One function per section, each with an optional year filter, replacing the
-- combined get_chicken_data. A screen calls only the function it needs.
--
-- About p_year: stored dates are lunar values, and the app can display them on
-- either calendar, so the server cannot filter on the exact year the user sees.
-- A lunar date in year Y falls in solar year Y or Y+1, and a batch is grouped
-- by its hatch date (incubation + 21 days), which can land in the year after
-- the one it was incubated in. Both shifts go the same way and are under a
-- year, so [p_year - 1, p_year] on the stored year is a superset of whatever
-- the client will show for p_year, on either calendar. The client then applies
-- its exact filter, so the extra year is invisible.
--
-- All three are SECURITY INVOKER: row level security still applies.

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

create or replace function public.get_global_cock_sales(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
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
      and (p_year is null
           or extract(year from s.date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;

create or replace function public.get_global_expenses(p_year int default null)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce((
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
      and (p_year is null
           or extract(year from e.date) between p_year - 1 and p_year)
  ), '[]'::jsonb);
$$;

-- The year pickers are built from the data on screen, so with a year filter in
-- place they would only ever offer the year already being shown. This keeps
-- them complete for a few hundred bytes.
create or replace function public.get_chicken_years()
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'batches', coalesce((
      select jsonb_agg(distinct extract(year from b.incubation_date)::int)
      from public.chicken_batches b
    ), '[]'::jsonb),
    'global_cock_sales', coalesce((
      select jsonb_agg(distinct extract(year from s.date)::int)
      from public.cock_sales s where s.batch_id is null
    ), '[]'::jsonb),
    'global_expenses', coalesce((
      select jsonb_agg(distinct extract(year from e.date)::int)
      from public.expenses e where e.batch_id is null
    ), '[]'::jsonb)
  );
$$;

drop function if exists public.get_chicken_data(text[]);

revoke execute on function public.get_chicken_batches(int) from public, anon;
revoke execute on function public.get_global_cock_sales(int) from public, anon;
revoke execute on function public.get_global_expenses(int) from public, anon;
revoke execute on function public.get_chicken_years() from public, anon;
grant execute on function public.get_chicken_batches(int) to authenticated;
grant execute on function public.get_global_cock_sales(int) to authenticated;
grant execute on function public.get_global_expenses(int) to authenticated;
grant execute on function public.get_chicken_years() to authenticated;;
