update public.movie_library
set
  movie_url = regexp_replace(movie_url, '^https?://[^/]+', '', 'i'),
  poster_url = regexp_replace(poster_url, '^https?://[^/]+', '', 'i');

alter table public.movie_library
  rename column movie_url to movie_path;

alter table public.movie_library
  rename column poster_url to poster_path;

alter table public.movie_library
  add constraint movie_library_movie_path_check
    check (movie_path ~ '^/'),
  add constraint movie_library_poster_path_check
    check (poster_path = '' or poster_path ~ '^/');

comment on column public.movie_library.movie_path is
  'Path relative to the currently configured movie server origin.';

comment on column public.movie_library.poster_path is
  'Poster path relative to the currently configured movie server origin.';
