-- 코드랩(CodeLab) 온라인 — Supabase → SQL Editor 에 통째로 붙여넣고 Run (여러 번 실행해도 안전)
-- 방·실시간 대전은 Supabase Realtime(채널)만 쓰므로 표가 필요 없다. 여기는 닉네임 · 레이팅 · 대전 기록만.
--
--   codelab_profiles : 계정당 한 줄. 코드랩 닉네임(영구, 중복 불가) + 레이팅
--   codelab_matches  : 온라인 대전 기록 (내 것만 보임)
--   함수(RPC)         : 닉네임 정하기 / 코드랩 초기화 / 대전 결과 저장(레이팅 계산)
-- 표에 직접 쓰기는 막고(RLS), 모든 쓰기는 아래 함수로만 한다.

-- ── 프로필 ─────────────────────────────────────────────
create table if not exists public.codelab_profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  nickname   text not null,
  rating     int  not null default 1000,
  games      int  not null default 0,
  wins       int  not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- 대소문자만 다른 닉네임도 같은 닉네임으로 본다
create unique index if not exists codelab_profiles_nickname_key on public.codelab_profiles (lower(nickname));
create index if not exists codelab_profiles_rating_idx on public.codelab_profiles (rating desc);

alter table public.codelab_profiles enable row level security;
drop policy if exists "코드랩 프로필 보기" on public.codelab_profiles;
create policy "코드랩 프로필 보기" on public.codelab_profiles for select using (true);   -- 랭킹·닉네임 표시용

-- ── 대전 기록 ──────────────────────────────────────────
create table if not exists public.codelab_matches (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  match_id      text not null,
  played_at     timestamptz not null default now(),
  players       int  not null,
  rank          int  not null,
  points        int  not null,
  cards         int  not null,
  rating_before int  not null,
  rating_after  int  not null,
  detail        jsonb not null default '[]'::jsonb,   -- [{nick, rank, points, cards}] 참가자 전체
  unique (user_id, match_id)
);
create index if not exists codelab_matches_user_idx on public.codelab_matches (user_id, played_at desc);

alter table public.codelab_matches enable row level security;
drop policy if exists "내 코드랩 기록 보기" on public.codelab_matches;
create policy "내 코드랩 기록 보기" on public.codelab_matches for select using (auth.uid() = user_id);

-- ── 닉네임 정하기 (한 번만. 바꾸려면 초기화) ─────────────
create or replace function public.codelab_claim_nickname(nick text)
returns public.codelab_profiles
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  n   text := btrim(coalesce(nick, ''));
  r   public.codelab_profiles;
begin
  if uid is null then raise exception 'not_signed_in'; end if;
  if n !~ '^[가-힣A-Za-z0-9_]{2,10}$' then raise exception 'bad_nickname'; end if;
  if exists (select 1 from public.codelab_profiles where user_id = uid) then
    raise exception 'already_has_nickname';
  end if;
  begin
    insert into public.codelab_profiles (user_id, nickname) values (uid, n) returning * into r;
  exception when unique_violation then
    raise exception 'nickname_taken';
  end;
  return r;
end $$;

-- ── 코드랩 초기화 (닉네임 + 레이팅 + 대전 기록 삭제) ─────
create or replace function public.codelab_reset_profile()
returns void
language plpgsql security definer set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_signed_in'; end if;
  delete from public.codelab_matches  where user_id = uid;
  delete from public.codelab_profiles where user_id = uid;
end $$;

-- ── 대전 결과 저장 (각자 자기 결과를 한 번 저장 → 레이팅 계산) ─
-- 레이팅 변화 = round((s − 0.4) × (20 + 5 × 인원)),  s = (인원 − 등수) / (인원 − 1)
--   6인전: 1등 +30 … 꼴등 −20  /  2인전: 이기면 +18, 지면 −12.  0 아래로는 안 내려감
create or replace function public.codelab_record_match(
  p_match_id text, p_players int, p_rank int, p_points int, p_cards int, p_detail jsonb
)
returns public.codelab_profiles
language plpgsql security definer set search_path = public
as $$
declare
  uid   uuid := auth.uid();
  prof  public.codelab_profiles;
  s     numeric;
  delta int;
  done  int;
begin
  if uid is null then raise exception 'not_signed_in'; end if;
  if p_players < 2 or p_players > 6 or p_rank < 1 or p_rank > p_players
     or p_points < 0 or p_points > 400 or p_cards < 0 or p_cards > 100
     or length(coalesce(p_match_id, '')) not between 6 and 64 then
    raise exception 'bad_result';
  end if;
  select * into prof from public.codelab_profiles where user_id = uid for update;
  if not found then raise exception 'no_profile'; end if;

  s := (p_players - p_rank)::numeric / (p_players - 1);
  delta := round((s - 0.4) * (20 + 5 * p_players));

  insert into public.codelab_matches
    (user_id, match_id, players, rank, points, cards, rating_before, rating_after, detail)
  values
    (uid, p_match_id, p_players, p_rank, p_points, p_cards, prof.rating, greatest(0, prof.rating + delta),
     coalesce(p_detail, '[]'::jsonb))
  on conflict (user_id, match_id) do nothing;
  get diagnostics done = row_count;
  if done = 0 then return prof; end if;   -- 같은 판을 두 번 저장하면 무시

  update public.codelab_profiles
     set rating = greatest(0, rating + delta),
         games = games + 1,
         wins = wins + case when p_rank = 1 then 1 else 0 end,
         updated_at = now()
   where user_id = uid
  returning * into prof;
  return prof;
end $$;

revoke all on function public.codelab_claim_nickname(text) from public, anon;
revoke all on function public.codelab_reset_profile() from public, anon;
revoke all on function public.codelab_record_match(text, int, int, int, int, jsonb) from public, anon;
grant execute on function public.codelab_claim_nickname(text) to authenticated;
grant execute on function public.codelab_reset_profile() to authenticated;
grant execute on function public.codelab_record_match(text, int, int, int, int, jsonb) to authenticated;

-- 실행 후 확인: 아래가 오류 없이 빈 결과면 준비 완료
-- select nickname, rating from public.codelab_profiles order by rating desc limit 5;
