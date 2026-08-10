alter table public.movie_library
  add column last_episode_name text,
  add column last_server_name text,
  add column last_position_seconds int;

comment on column public.movie_library.last_episode_name is
  'Name of the last episode watched for this movie.';

comment on column public.movie_library.last_server_name is
  'Name of the server the last episode was watched on.';

comment on column public.movie_library.last_position_seconds is
  'Playback position in seconds within the last watched episode.';
