-- 코드랩 레이팅 계산 v2 (Supabase → SQL Editor 에서 한 번 실행 — 다시 실행해도 됨)
-- 2026-11-04 사용자 요청:
--   ① 레이팅 변화가 '이번 판 상대들의 평균 레이팅'과 내 레이팅의 관계를 반영 (Elo 식)
--   ② 그 판에서 얻은 포인트도 반영 (순위 70% + 포인트 30%)
--   ③ 판마다 '참가 보상' — 다 같이 비슷하게 하면 1020·1010·990·980 처럼 제자리라 아쉬움 →
--      끝까지 한 사람은 +2 + 포인트/20 (최대 +7, 기권은 0). 하다 보면 조금씩 올라간다.
--   ④ 지금까지 한 판수 × 4 를 한 번만 보상 (맨 아래, bonus_given 으로 두 번 안 줌)
--
--   K  = 20 + 5 × 인원              (인원이 많을수록 크게 오르내림 — 예전과 같은 크기)
--   순위 몫  = (인원 − 내 순위) / (인원 − 1)              (1등 1, 꼴등 0)
--   포인트 몫 = (내 포인트 − 최저) / (최고 − 최저)        (그 판 참가자 중 1등 포인트 1, 꼴찌 포인트 0. 모두 같으면 순위 몫)
--   실제 S = 0.7 × 순위 몫 + 0.3 × 포인트 몫
--   기대 E = 1 / (1 + 10^((상대 평균 − 내 레이팅) / 400))   (체스 Elo 와 같은 식)
--   변화 = round(K × (S − E)) + 참가 보상
-- 예) 4명, 모두 1000점, 포인트 100·90·40·10: 1등 +20 · 2등 +9 · 3등 −7 · 꼴등 −20
--     (포인트가 100·50·45·40 이면 2등 +1 · 3등 −10 — 1등과 차이가 클수록 덜 오름)
--     내가 1400, 상대 평균 1000: 1등 +4 · 꼴등 −36   /  내가 1000, 상대 평균 1400: 1등 +36 · 꼴등 −4
-- 게임이 p_avg 를 넘기고, 이 함수가 없으면 게임은 옛 함수(p_avg 없음)로 저장한다.
-- 다른 참가자의 포인트는 게임이 보내는 p_detail(참가자별 결과)에서 읽는다.

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
  sp    numeric;
  pmax  numeric;
  pmin  numeric;
  e     numeric;
  k     numeric;
  bonus int;
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
  -- 포인트 몫: 이번 판 참가자들(p_detail) 포인트 중 내 위치
  select max(greatest(0, least(400, coalesce((x->>'points')::numeric, 0)))),
         min(greatest(0, least(400, coalesce((x->>'points')::numeric, 0))))
    into pmax, pmin
    from jsonb_array_elements(case when jsonb_typeof(p_detail) = 'array' then p_detail else '[]'::jsonb end) x;
  pmax := greatest(coalesce(pmax, p_points), p_points);
  pmin := least(coalesce(pmin, p_points), p_points);
  sp := case when pmax > pmin then (p_points - pmin) / (pmax - pmin) else s end;
  s := 0.7 * s + 0.3 * sp;
  e := 1 / (1 + power(10::numeric, (p_avg - prof.rating)::numeric / 400));
  delta := round(k * (s - e));
  -- 참가 보상: 끝까지 한 사람만 (p_detail 에서 내 줄의 left 로 기권 확인)
  bonus := case when exists (
             select 1 from jsonb_array_elements(case when jsonb_typeof(p_detail) = 'array' then p_detail else '[]'::jsonb end) x
              where x->>'nick' = prof.nickname and coalesce((x->>'left')::boolean, false))
           then 0 else least(7, 2 + round(p_points / 20.0))::int end;
  delta := delta + bonus;

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

-- ④ 한 번만: 지금까지 한 판수 × 4 보상 (다시 실행해도 bonus_given 이 true 면 안 줌)
alter table public.codelab_profiles add column if not exists bonus_given boolean not null default false;
update public.codelab_profiles
   set rating = rating + games * 4, bonus_given = true, updated_at = now()
 where not bonus_given;
