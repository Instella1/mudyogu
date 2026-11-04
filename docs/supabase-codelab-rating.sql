-- 코드랩 레이팅 계산 v2 (Supabase → SQL Editor 에서 한 번 실행)
-- 2026-11-04 사용자 요청: 레이팅 변화가 '이번 판 참가자들의 평균 레이팅'과 내 레이팅의 관계를 반영하도록.
--
--   K  = 20 + 5 × 인원              (인원이 많을수록 크게 오르내림 — 예전과 같은 크기)
--   실제 S = (인원 − 내 순위) / (인원 − 1)   (1등 1, 꼴등 0)
--   기대 E = 1 / (1 + 10^((상대 평균 − 내 레이팅) / 400))   (체스 Elo 와 같은 식)
--   변화 = round(K × (S − E))
-- 예) 4명, 모두 1000점: 1등 +20 · 2등 +7 · 3등 −7 · 꼴등 −20
--     내가 1400, 상대 평균 1000: 1등 +4 · 꼴등 −36   /  내가 1000, 상대 평균 1400: 1등 +36 · 꼴등 −4
-- 게임이 p_avg 를 넘기고, 이 함수가 없으면 게임은 옛 함수(p_avg 없음)로 저장한다.

create or replace function public.codelab_record_match(
  p_match_id text, p_players int, p_rank int, p_points int, p_cards int, p_detail jsonb, p_avg int
)
returns public.codelab_profiles
language plpgsql security definer set search_path = public
as $$
declare
  uid   uuid := auth.uid();
  prof  public.codelab_profiles;
  s     numeric;
  e     numeric;
  k     numeric;
  delta int;
  done  int;
begin
  if uid is null then raise exception 'not_signed_in'; end if;
  if p_players < 2 or p_players > 6 or p_rank < 1 or p_rank > p_players
     or p_points < 0 or p_points > 400 or p_cards < 0 or p_cards > 100
     or p_avg < 0 or p_avg > 10000
     or length(coalesce(p_match_id, '')) not between 6 and 64 then
    raise exception 'bad_result';
  end if;
  select * into prof from public.codelab_profiles where user_id = uid for update;
  if not found then raise exception 'no_profile'; end if;

  k := 20 + 5 * p_players;
  s := (p_players - p_rank)::numeric / (p_players - 1);
  e := 1 / (1 + power(10::numeric, (p_avg - prof.rating)::numeric / 400));
  delta := round(k * (s - e));

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

revoke all on function public.codelab_record_match(text, int, int, int, int, jsonb, int) from public, anon;
grant execute on function public.codelab_record_match(text, int, int, int, int, jsonb, int) to authenticated;
