-- Run to Heaven: the public leaderboard.
-- One row per player. The player id is a random id kept in that player's browser; it is never readable.
-- Anyone can read names and scores. The only way to write is submit_score(), which checks each score.

create table if not exists public.scores (
  player_id    uuid primary key,
  tag          text not null unique,          -- sha-256 of player_id: lets a browser find its own row
  name         text not null check (char_length(name) between 1 and 20),
  distance     integer not null check (distance between 0 and 500000),
  level        smallint not null check (level between 1 and 10),
  books        smallint not null default 0 check (books between 0 and 66),
  completed    boolean not null default false,
  "character"  text not null default 'Noah' check (char_length("character") <= 20),
  repents      integer not null default 0 check (repents between 0 and 100000),
  play_seconds integer not null default 0 check (play_seconds between 0 and 100000000),
  updated_at   timestamptz not null default now()
);
create index if not exists scores_rank on public.scores (distance desc, updated_at asc);

alter table public.scores enable row level security;
drop policy if exists "Scores are public to read" on public.scores;
create policy "Scores are public to read" on public.scores for select to anon, authenticated using (true);

-- Readers see these columns only (not player_id), and nobody writes the table directly.
revoke all on table public.scores from anon, authenticated;
grant select (tag, name, distance, level, completed, repents, updated_at) on public.scores to anon, authenticated;

create or replace function public.submit_score(
  p_player uuid, p_name text, p_distance integer, p_level integer, p_books integer,
  p_completed boolean, p_character text, p_repents integer, p_play_seconds integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := left(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 20);
  v_tag  text := encode(sha256(convert_to(p_player::text, 'UTF8')), 'hex');
  v_old  integer;
begin
  if p_player is null then raise exception 'player id needed'; end if;
  if char_length(v_name) < 1 then raise exception 'name needed'; end if;
  if lower(regexp_replace(v_name, '[^a-zA-Z]', '', 'g')) ~ '(fuck|shit|cunt|nigg|fagg|bitch|whore|slut|porn|penis|vagin|hitler|asshole|retard|twat|wank|bollock|motherf|dildo|blowjob)' then
    raise exception 'name not allowed';
  end if;
  if p_distance is null or p_distance < 0 or p_level is null or p_level not between 1 and 10
     or coalesce(p_books, 0) not between 0 and 66 then
    raise exception 'bad score';
  end if;
  -- no run is faster than about 60 m for each second of play
  if p_distance > greatest(coalesce(p_play_seconds, 0), 0) * 60 + 200 then raise exception 'score not possible'; end if;

  select distance into v_old from public.scores where player_id = p_player;
  if v_old is null then
    insert into public.scores (player_id, tag, name, distance, level, books, completed, "character", repents, play_seconds)
    values (p_player, v_tag, v_name, p_distance, p_level, coalesce(p_books, 0), coalesce(p_completed, false),
            left(coalesce(p_character, 'Noah'), 20), greatest(coalesce(p_repents, 0), 0), greatest(coalesce(p_play_seconds, 0), 0));
    return jsonb_build_object('saved', true, 'best', p_distance);
  elsif p_distance > v_old then
    update public.scores
       set name = v_name, distance = p_distance, level = p_level, books = coalesce(p_books, 0),
           completed = coalesce(p_completed, false), "character" = left(coalesce(p_character, 'Noah'), 20),
           repents = greatest(coalesce(p_repents, 0), 0), play_seconds = greatest(coalesce(p_play_seconds, 0), 0),
           updated_at = now()
     where player_id = p_player;
    return jsonb_build_object('saved', true, 'best', p_distance);
  else
    -- a lower score does not replace the best one; the row takes the name typed this time
    update public.scores set name = v_name where player_id = p_player and name is distinct from v_name;
    return jsonb_build_object('saved', false, 'best', v_old);
  end if;
end;
$$;

revoke all on function public.submit_score(uuid, text, integer, integer, integer, boolean, text, integer, integer) from public;
grant execute on function public.submit_score(uuid, text, integer, integer, integer, boolean, text, integer, integer) to anon, authenticated;
