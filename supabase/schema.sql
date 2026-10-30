-- Badminton Courtside database. Paste this whole file into Supabase → SQL Editor → Run.
-- Safe to run again: it only creates what's missing and replaces the functions.
--
-- Who can do what:
--   anyone with the site link  → read players and matches
--   anyone with the team PIN   → add/remove players, log/edit/delete matches (via the functions below)
-- Nobody can write to the tables directly, and the PIN hash is never readable.

create extension if not exists pgcrypto with schema extensions;

-- ---------- tables ----------
create table if not exists public.players (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(btrim(name)) between 1 and 30),
  created_at timestamptz not null default now()
);
create unique index if not exists players_name_key on public.players (lower(name));

create table if not exists public.matches (
  id         uuid primary key default gen_random_uuid(),
  played_on  date not null default current_date,
  created_at timestamptz not null default now(),
  team_a     uuid[] not null,
  team_b     uuid[] not null,
  score_a    int not null check (score_a between 0 and 99),
  score_b    int not null check (score_b between 0 and 99),
  winner     text generated always as (case when score_a > score_b then 'a' else 'b' end) stored,
  check (score_a <> score_b),
  check (cardinality(team_a) between 1 and 2 and cardinality(team_a) = cardinality(team_b))
);

create table if not exists public.team_secret (
  id       int primary key default 1 check (id = 1),
  pin_hash text not null
);

-- ---------- access ----------
alter table public.players     enable row level security;
alter table public.matches     enable row level security;
alter table public.team_secret enable row level security;

drop policy if exists "anyone can read players" on public.players;
drop policy if exists "anyone can read matches" on public.matches;
create policy "anyone can read players" on public.players for select using (true);
create policy "anyone can read matches" on public.matches for select using (true);
-- team_secret has no policies, so the API can never read it.

revoke insert, update, delete on public.players, public.matches from anon, authenticated;
revoke all on public.team_secret from anon, authenticated;

-- ---------- PIN check ----------
create or replace function public._pin_ok(pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from public.team_secret where pin_hash = crypt(coalesce(pin, ''), pin_hash));
$$;
revoke execute on function public._pin_ok(text) from public, anon, authenticated;

-- Used by the Unlock button. The short sleep makes guessing PINs slow.
create or replace function public.check_pin(pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.4);
  return public._pin_ok(pin);
end $$;

-- ---------- write functions ----------
create or replace function public.add_player(pin text, p_name text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare new_id uuid;
begin
  if not public._pin_ok(pin) then raise exception 'wrong_pin'; end if;
  insert into public.players (name) values (btrim(p_name)) returning id into new_id;
  return new_id;
end $$;

create or replace function public.remove_player(pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public._pin_ok(pin) then raise exception 'wrong_pin'; end if;
  if exists (select 1 from public.matches where p_id = any(team_a) or p_id = any(team_b)) then
    raise exception 'player_has_matches';
  end if;
  delete from public.players where id = p_id;
end $$;

create or replace function public.add_match(
  pin text, p_played_on date, p_team_a uuid[], p_team_b uuid[], p_score_a int, p_score_b int
) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare
  everyone uuid[] := p_team_a || p_team_b;
  new_id uuid;
begin
  if not public._pin_ok(pin) then raise exception 'wrong_pin'; end if;
  if (select count(distinct x) from unnest(everyone) x) <> cardinality(everyone) then
    raise exception 'duplicate_player';
  end if;
  if (select count(*) from public.players where id = any(everyone)) <> cardinality(everyone) then
    raise exception 'unknown_player';
  end if;
  insert into public.matches (played_on, team_a, team_b, score_a, score_b)
  values (coalesce(p_played_on, current_date), p_team_a, p_team_b, p_score_a, p_score_b)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.update_match(
  pin text, p_id uuid, p_played_on date, p_team_a uuid[], p_team_b uuid[], p_score_a int, p_score_b int
) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare everyone uuid[] := p_team_a || p_team_b;
begin
  if not public._pin_ok(pin) then raise exception 'wrong_pin'; end if;
  if (select count(distinct x) from unnest(everyone) x) <> cardinality(everyone) then
    raise exception 'duplicate_player';
  end if;
  if (select count(*) from public.players where id = any(everyone)) <> cardinality(everyone) then
    raise exception 'unknown_player';
  end if;
  update public.matches
     set played_on = coalesce(p_played_on, played_on), team_a = p_team_a, team_b = p_team_b,
         score_a = p_score_a, score_b = p_score_b
   where id = p_id;
  if not found then raise exception 'match_not_found'; end if;
end $$;

create or replace function public.delete_match(pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public._pin_ok(pin) then raise exception 'wrong_pin'; end if;
  delete from public.matches where id = p_id;
end $$;

grant execute on function public.check_pin(text)                                to anon, authenticated;
grant execute on function public.add_player(text, text)                         to anon, authenticated;
grant execute on function public.remove_player(text, uuid)                      to anon, authenticated;
grant execute on function public.add_match(text, date, uuid[], uuid[], int, int) to anon, authenticated;
grant execute on function public.update_match(text, uuid, date, uuid[], uuid[], int, int) to anon, authenticated;
grant execute on function public.delete_match(text, uuid)                       to anon, authenticated;

-- ---------- live updates ----------
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'players') then
    alter publication supabase_realtime add table public.players;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'matches') then
    alter publication supabase_realtime add table public.matches;
  end if;
end $$;
