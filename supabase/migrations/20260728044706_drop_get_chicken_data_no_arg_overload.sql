-- The parameterised version has a default, so the no-argument overload left
-- behind by the previous migration would make get_chicken_data() ambiguous.
drop function if exists public.get_chicken_data();;
