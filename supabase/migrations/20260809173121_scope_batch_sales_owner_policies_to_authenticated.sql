-- The owner policies on batch_sales were created for the `public` role while
-- every other table scopes its owner policies to `authenticated`. Anonymous
-- requests were never able to match them (auth.uid() is null, so the
-- `auth.uid() = user_id` check yields null), but Postgres still evaluated the
-- policies for them. Scope the four policies like the rest of the schema.
alter policy "owner select" on public.batch_sales to authenticated;
alter policy "owner insert" on public.batch_sales to authenticated;
alter policy "owner update" on public.batch_sales to authenticated;
alter policy "owner delete" on public.batch_sales to authenticated;
